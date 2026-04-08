defmodule Lobber.Channels.Discord.Socket do
  @moduledoc """
  Primary implementation against discord's websocket gateway
  """
  use GenServer

  require Logger

  alias Lobber.Channels.Discord.DiscordMessage
  alias Lobber.Conversation
  alias Lobber.Channels.Discord.Client

  @heartbeat_ack_timeout 10_000

  def start_link(state) do
    {channel_name, _state} = Keyword.pop(state, :channel_name)
    GenServer.start_link(__MODULE__, %{channel_name: channel_name}, name: __MODULE__)
  end

  @impl true
  def init(%{channel_name: channel_name}) do
    Logger.info("Starting discord...")

    client = Client.client()

    %{"url" => websock_url} = Tesla.get!(client, "/api/gateway/bot").body

    Logger.debug("Connecting to #{websock_url}")
    websock_url = URI.parse(websock_url)

    Logger.debug("Initiating connection to #{websock_url.host}")
    {:ok, conn} = :gun.open(to_charlist(websock_url.host), 443, %{protocols: [:http]})
    Logger.debug("Connection established")

    {:ok,
     %{
       channel_name: channel_name,
       conn: conn,
       ref: nil,
       status: :connecting,
       data: nil,
       heartbeat_interval: nil,
       sequence_number: nil,
       resume_url: nil,
       heartbeat_acknowledged: true,
       session_id: nil,
       client: client,
       user_id: nil,
       application_id: nil
     }}
  end

  defp next_heartbeat(interval) do
    (interval * :rand.uniform())
    |> floor()
  end

  defp reconnect(%{conn: conn, resume_url: websock_url} = state) do
    Logger.info("Reconnecting to #{websock_url}...")
    :gun.shutdown(conn)
    websock_url = URI.parse(websock_url)
    {:ok, conn} = :gun.open(to_charlist(websock_url.host), 443, %{protocols: [:http]})

    # reconnects don't need an upgrade
    %{
      state
      | conn: conn,
        ref: nil,
        status: :connecting
    }
  end

  @impl true
  def handle_info({:gun_up, _pid, :http}, %{status: :connecting, conn: conn} = state) do
    Logger.debug("Upgrading to websocket")
    ref = :gun.ws_upgrade(conn, "/?v=10&encoding=json", Client.headers())

    {
      :noreply,
      %{state | status: :upgrading, ref: ref}
    }
  end

  @impl true
  def handle_info({:gun_upgrade, _pid, _ref, _, _}, %{status: :upgrading} = state) do
    Logger.debug("Upgraded")

    # once we're up and have confirmed valid creds, we can start command registration
    # this shouldn't be in our context though, we do not care if it completes
    Task.start(Lobber.Channels.Discord.Commands, :create_commands, [])
    my_id = Lobber.Channels.Discord.Commands.my_id()
    Logger.info("We are #{my_id}")

    {
      :noreply,
      %{state | status: :connected, application_id: my_id}
    }
  end

  def handle_info({:gun_down, _pid, :ws, _reason, _ref}, state) do
    {:noreply, reconnect(state)}
  end

  @impl true
  def handle_info(message, %{status: :upgrading} = state) do
    Logger.error("Unexpected upgrade message")
    IO.inspect(message)
    {:stop, state}
  end

  @impl true
  def handle_info(
        :heartbeat,
        %{
          conn: conn,
          ref: websocket_ref,
          sequence_number: seq,
          heartbeat_acknowledged: true
        } = state
      ) do
    Logger.debug("Sending heartbeat #{seq}")

    {:ok, hb_frame} =
      %DiscordMessage{
        opcode: :heartbeat,
        data: seq
      }
      |> DiscordMessage.encode()

    :ok = :gun.ws_send(conn, websocket_ref, {:text, hb_frame})

    Process.send_after(self(), :heartbeat_ack_check, @heartbeat_ack_timeout)
    {:noreply, %{state | heartbeat_acknowledged: false}}
  end

  def handle_info(
        :heartbeat,
        %{heartbeat_acknowledged: false} = state
      ) do
    # if we reconnected, don't bother sending the heartbeat, it'll be rescheduled
    {:noreply, state}
  end

  def handle_info(
        :heartbeat_ack_check,
        %{heartbeat_acknowledged: true} = state
      ) do
    Logger.debug("We're good")
    {:noreply, state}
  end

  def handle_info(
        :heartbeat_ack_check,
        state
      ) do
    Logger.debug("oops! Heartbeat was not acknowledged. We have to reconnect...")

    {:noreply, reconnect(state)}
  end

  def handle_info({:gun_ws, _pid, _ref, {:close, 1001, ""}}, state) do
    {:noreply, state}
  end

  def handle_info({:gun_ws, _pid, _ref, frame}, %{status: :connected} = state) do
    case handle_frame(frame, state) do
      {:stop, _, _} = resp -> resp
      %{} = state -> {:noreply, state}
    end
  end

  defp handle_frame({:text, frame}, state) do
    message =
      frame
      |> DiscordMessage.decode()

    state = handle_sequence(message, state)

    handle_data(message, state)
  end

  defp handle_sequence(%DiscordMessage{sequence_number: s}, state) when not is_nil(s) do
    %{state | sequence_number: s}
  end

  defp handle_sequence(_, state), do: state

  defp handle_data(
         %DiscordMessage{
           opcode: :dispatch,
           type: "READY",
           data: %{"user" => %{"username" => username, "id" => id}}
         } = message,
         state
       ) do
    Logger.debug("Discord is ready, hello #{username}!")

    %DiscordMessage{
      data: %{
        "resume_gateway_url" => resume_url,
        "session_id" => session_id
      }
    } = message

    %{state | resume_url: resume_url, session_id: session_id, user_id: id}
  end

  defp handle_data(
         %DiscordMessage{
           opcode: :dispatch,
           type: "RESUMED"
         },
         state
       ) do
    Logger.info("Discord resumed!")

    state
  end

  defp handle_data(
         %DiscordMessage{
           opcode: :dispatch,
           type: "MESSAGE_CREATE",
           data: %{
             "author" => %{"id" => id}
           }
         },
         %{user_id: user_id} = state
       )
       when id == user_id,
       do: state

  defp handle_data(
         %{
           opcode: :dispatch,
           type: "MESSAGE_CREATE",
           data: %{
             "author" => %{"username" => username},
             "content" => content,
             "channel_id" => channel_id
           }
         },
         %{channel_name: channel_name} = state
       ) do
    Logger.debug("#{username}: #{content}")

    case with_conversation(channel_name, channel_id, state) do
      {:ok, conversation} ->
        Lobber.Conversation.add_message(
          conversation,
          self(),
          content,
          %{channel_id: channel_id}
        )

        state

      :error ->
        state
    end
  end

  defp handle_data(
         %{opcode: :dispatch, type: "INTERACTION_CREATE", data: data},
         %{channel_name: channel_name} = state
       ) do
    %{
      "id" => interaction_id,
      "token" => interaction_token,
      "data" => cmd_data,
      "channel_id" => channel_id
    } = data

    case with_conversation(channel_name, channel_id, state) do
      {:ok, conversation} ->
        callback = "/api/v10/interactions/#{interaction_id}/#{interaction_token}/callback"

        {:ok, _data} =
          Tesla.post(Client.client(), callback, %{
            type: 4,
            data: %{
              content: "Started!"
            }
          })

        Lobber.Conversation.add_message(
          conversation,
          self(),
          Lobber.Channels.Discord.Commands.format(cmd_data),
          %{channel_id: channel_id}
        )

        state

      :error ->
        state
    end
  end

  defp handle_data(
         %{
           opcode: :dispatch,
           type: "MESSAGE_UPDATE"
         },
         state
       ) do
    state
  end

  defp handle_data(
         %DiscordMessage{
           opcode: :hello,
           data: %{
             "heartbeat_interval" => heartbeat
           }
         },
         state
       ) do
    Logger.debug("HELLO recieved! Interval #{heartbeat}")
    hb_in = next_heartbeat(heartbeat)
    Process.send_after(self(), :heartbeat, hb_in)

    # now we've been welcomed, we need to identify ourselves
    if is_nil(state.session_id) do
      {:ok, handshake_frame} =
        %DiscordMessage{
          opcode: :identify,
          data: %{
            token: Client.bot_token(),
            properties: %{
              os: "Linux",
              browser: "YuiBot",
              device: "YuiBot"
            },
            presence: %{
              activities: [],
              status: "online"
            },
            intents: 4096
          }
        }
        |> DiscordMessage.encode()

      :ok = :gun.ws_send(state.conn, state.ref, {:text, handshake_frame})

      %{
        state
        | heartbeat_interval: heartbeat
      }
    else
      # resume time
      Logger.debug("Resuming session #{state.session_id}")

      {:ok, resume_frame} =
        %DiscordMessage{
          opcode: :resume,
          data: %{
            token: Client.bot_token(),
            session_id: state.session_id,
            seq: state.sequence_number
          }
        }
        |> DiscordMessage.encode()

      :ok = :gun.ws_send(state.conn, state.ref, {:text, resume_frame})

      %{
        state
        | heartbeat_interval: heartbeat
      }
    end
  end

  defp handle_data(
         %DiscordMessage{
           opcode: :heartbeat_ACK
         },
         %{heartbeat_interval: heartbeat} = state
       ) do
    # Heartbeat response. Schedule the next heartbeat
    Logger.debug("Heartbeat response recieved, scheduling next (interval: #{heartbeat})")
    next_hb = next_heartbeat(heartbeat)
    Process.send_after(self(), :heartbeat, next_hb)
    %{state | heartbeat_acknowledged: true}
  end

  defp handle_data(
         %DiscordMessage{
           opcode: :reconnect
         },
         state
       ) do
    reconnect(state)
  end

  defp handle_data(%DiscordMessage{opcode: :invalid_session}, state) do
    # alright we've tried to resume and been told no, we crash
    {:stop, :ws_died, state}
  end

  defp handle_data(other, state) do
    Logger.warning("Unhandled discord frame: #{inspect(other)}")
    state
  end

  @impl true
  def handle_cast(
        {:conversation_response, %Conversation.Message{} = message, %{channel_id: channel_id}},
        %{client: client} = state
      ) do
    send_message(client, channel_id, message.content)
    {:noreply, state}
  end

  defp send_message(client, channel_id, message) do
    {:ok, body} =
      Jason.encode(%{
        content: message
      })

    Tesla.post(
      client,
      "/api/v10/channels/#{channel_id}/messages",
      body
    )
  end

  defp with_conversation(channel_name, channel_id, state) do
    case Lobber.Conversations.get_or_spawn(channel_name, channel_id) do
      {:ok, conversation} ->
        {:ok, conversation}

      {:error, :needs_auth, id} ->
        send_message(state.client, channel_id, "LOBBER NEED AUTH! Pair with id #{id} pls :<")
        :error
    end
  end
end
