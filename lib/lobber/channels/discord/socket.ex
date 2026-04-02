defmodule Lobber.Channels.Discord.Socket do
  @moduledoc """
  Primary implementation against discord's websocket gateway
  """
  use GenServer

  require Logger

  alias Lobber.Channels.Discord.DiscordMessage
  alias Lobber.Conversation

  @discord "https://discord.com"
  @heartbeat_ack_timeout 10_000

  def start_link(state) do
    {channel_name, _state} = Keyword.pop(state, :channel_name)
    GenServer.start_link(__MODULE__, %{channel_name: channel_name}, name: __MODULE__)
  end

  @impl true
  def init(%{channel_name: channel_name}) do
    Logger.info("Starting discord...")

    client =
      Tesla.client([
        {Tesla.Middleware.BaseUrl, @discord},
        {Tesla.Middleware.Headers, [{"content-type", "application/json"} | headers()]},
        Tesla.Middleware.JSON,
        {Tesla.Middleware.Timeout, timeout: 10_000}
      ])

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
       resp_headers: nil,
       resp_status: nil,
       data: nil,
       heartbeat_interval: nil,
       sequence_number: nil,
       resume_url: nil,
       heartbeat_acknowledged: true,
       session_id: nil,
       client: client,
       user_id: nil
     }}
  end

  defp bot_token do
    Lobber.Config.get(Lobber.Channels.Discord, :bot_token)
  end

  defp headers do
    [
      {"user-agent", "YuiBot (application 182675940042735616)"},
      {"authorization", "Bot #{bot_token()}"}
    ]
  end

  defp next_heartbeat(interval) do
    (interval * :rand.uniform())
    |> floor()
  end

  defp reconnect(%{conn: conn, resume_url: websock_url} = state) do
    :gun.shutdown(conn)
    websock_url = URI.parse(websock_url)
    {:ok, conn} = :gun.open(to_charlist(websock_url.host), 443, %{protocols: [:http]})

    {:noreply,
     %{
       state
       | conn: conn,
         ref: nil,
         status: :connecting
     }}
  end

  @impl true
  def handle_info({:gun_up, _pid, _opts}, %{status: :connecting, conn: conn} = state) do
    Logger.debug("Upgrading to websocket")
    ref = :gun.ws_upgrade(conn, "/?v=10&encoding=json", headers())

    {
      :noreply,
      %{state | status: :upgrading, ref: ref}
    }
  end

  @impl true
  def handle_info({:gun_upgrade, _pid, _ref, _, _}, %{status: :upgrading} = state) do
    Logger.debug("Upgraded")

    {
      :noreply,
      %{state | status: :connected}
    }
  end

  @impl true
  def handle_info(_message, %{status: :upgrading} = state) do
    Logger.error("Unexpected upgrade message")
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
        state
      ) do
    Logger.debug("oops! Heartbeat was not acknowledged. We have to reconnect...")

    reconnect(state)
  end

  def handle_info(
        :heartbeat_ack_check,
        %{heartbeat_acknowledged: true} = state
      ) do
    Logger.debug("We're good")
    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_ws, _pid, _ref, frame}, %{status: :connected} = state) do
    {:noreply, handle_frame(frame, state)}
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

    case Lobber.Conversations.get_or_spawn(channel_name, channel_id) do
      {:ok, conversation} ->
        Lobber.Conversation.add_message(
          conversation,
          self(),
          content,
          %{channel_id: channel_id}
        )

        state

      {:error, :needs_auth, id} ->
        send_message(state.client, channel_id, "LOBBER NEED AUTH! Pair with id #{id} pls :<")
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
    {:noreply, state}
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
            token: bot_token(),
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
      Logger.debug("Resuming session")

      {:ok, resume_frame} =
        %DiscordMessage{
          opcode: :resume,
          data: %{
            token: bot_token(),
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

  defp handle_data(other, state) do
    Logger.warning("Unhandled discord frame: #{other}")
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
end
