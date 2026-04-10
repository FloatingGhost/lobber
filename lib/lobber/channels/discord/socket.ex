defmodule Lobber.Channels.Discord.Socket do
  @moduledoc """
  Primary implementation against discord's websocket gateway

  state transitions:
  connecting
    -> upgrading
      -> connected
        -> closing_for_reconnect
          <-- to start
  """
  use GenServer

  require Logger

  alias Lobber.Channels.Discord.DiscordMessage
  alias Lobber.Conversation
  alias Lobber.Channels.Discord.Client

  def start_link(state) do
    {channel_name, _state} = Keyword.pop(state, :channel_name)

    GenServer.start_link(__MODULE__, %{channel_name: channel_name},
      name: {:via, Registry, {Lobber.Channels.registry(), :discord_socket}}
    )
  end

  @impl true
  def init(%{channel_name: channel_name}) do
    Logger.info("Starting discord...")

    client = Client.client()

    %{"url" => websock_url} = Tesla.get!(client, "/api/gateway/bot").body

    {:ok,
     connect(
       %{
         channel_name: channel_name,
         conn: nil,
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
       },
       websock_url
     )}
  end

  ## CONNECTION MANAGEMENT BE HERE ##
  ## do not gaze upon this or ye shall go insane ##
  defp next_heartbeat(interval) do
    (interval * :rand.uniform())
    |> floor()
  end

  defp connect(state, websock_url) do
    Logger.debug("Connecting to #{websock_url}")
    websock_url = URI.parse(websock_url)
    {:ok, conn} = :gun.open(to_charlist(websock_url.host), 443, %{protocols: [:http]})
    Logger.debug("Connection established")

    %{
      state
      | status: :connecting,
        conn: conn
    }
  end

  defp reconnect(%{conn: conn, ref: websocket_ref} = state) do
    Logger.info("Closing websocket")
    :gun.ws_send(conn, websocket_ref, {:close, 4000, "Reconnecting"})

    # if we don't get the close event for 10s, we'll execute the connection
    Process.send_after(self(), :reconnect_timeout, 10_000)

    %{
      state
      | status: :closing_for_reconnect
    }
  end

  # sent on conn start
  @impl true
  def handle_info({:gun_up, _pid, :http}, %{status: :connecting, conn: conn} = state) do
    Logger.debug("Upgrading to websocket")
    ref = :gun.ws_upgrade(conn, "/?v=10&encoding=json", Client.headers())

    {
      :noreply,
      %{state | status: :upgrading, ref: ref}
    }
  end

  # sent when we've got a real websocket
  def handle_info({:gun_upgrade, _pid, _ref, _, _}, %{status: :upgrading} = state) do
    Logger.debug("Upgraded")

    my_id = Lobber.Channels.Discord.Commands.my_id()
    Logger.info("We are #{my_id}")

    {
      :noreply,
      %{state | status: :connected, application_id: my_id}
    }
  end

  # gun has died for some reason
  def handle_info({:gun_down, _pid, :ws, reason, _ref}, %{resume_url: url} = state) do
    Logger.info("Websocket conn has closed unexpectedly - #{inspect(reason)}")
    {:noreply, connect(%{state | status: :connecting}, url)}
  end

  # remote side DC'd us?
  def handle_info({:gun_ws, _pid, _ref, {:close, 1001, ""}}, %{resume_url: url} = state) do
    Logger.info("Websocket has closed (code 1001), reconnecting!")
    {:noreply, connect(%{state | status: :connecting}, url)}
  end

  # our DC has gone through and we can gracefully reconnect
  def handle_info(
        {:gun_ws, pid, _ref, {:close, 4000, _}},
        %{resume_url: url, status: :closing_for_reconnect} = state
      ) do
    Logger.debug("Disconnect is good! Shutting down old pid")
    :ok = :gun.close(pid)
    {:noreply, connect(%{state | status: :connecting}, url)}
  end

  def handle_info({:gun_ws, _pid, _ref, frame}, %{status: :connected} = state) do
    case handle_frame(frame, state) do
      {:stop, _, _} = stop_frame -> stop_frame
      %{} = new_state -> {:noreply, new_state}
    end
  end

  def handle_info(
        {:gun_ws, _pid, _ref, frame},
        %{status: :closing_for_reconnect} = state
      ) do
    # race condition! we didn't get a heartbeat ACK and we're in the process of closing things
    {:noreply, state}
  end

  # we tried to gracefully close the websocket but didn't get a confirm
  def handle_info(
        :reconnect_timeout,
        %{conn: conn, status: :closing_for_reconnect, resume_url: url} = state
      ) do
    # oops! no reconnect
    # obliterate the conn
    Logger.info("Reconnect timeout, closing websocket with no mercy")
    :ok = :gun.close(conn)
    {:noreply, connect(%{state | status: :connecting}, url)}
  end

  # the reconnect timeout check fired but we did manage to succeed
  # ignore
  def handle_info(
        :reconnect_timeout,
        state
      ) do
    {:noreply, state}
  end

  # scheduled heartbeat task, when our last heartbeat was ACKed
  def handle_info(
        :heartbeat,
        %{
          conn: conn,
          ref: websocket_ref,
          sequence_number: seq,
          heartbeat_acknowledged: true,
          status: :connected
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

  # and when we didn't get ACKed
  def handle_info(
        :heartbeat,
        %{heartbeat_acknowledged: false, status: :connected} = state
      ) do
    # this is bad! we need to reconnect
    {:noreply, reconnect(state)}
  end

  # the scheduled task fired, but we're not in a connected state, ignore this message
  def handle_info(
        :heartbeat,
        state
      ) do
    {:noreply, state}
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
         } = message,
         %{heartbeat_interval: heartbeat} = state
       ) do
    Logger.info("Discord resumed!")
    Logger.debug(inspect(message))
    next_hb = next_heartbeat(heartbeat)
    Process.send_after(self(), :heartbeat, next_hb)
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
           data:
             %{
               "author" => %{"username" => username},
               "content" => content,
               "channel_id" => channel_id,
               "attachments" => attachments
             } = data
         },
         %{channel_name: channel_name} = state
       ) do
    Logger.debug("#{username}: #{content}")

    attachment_urls =
      attachments
      |> Enum.filter(fn att ->
        att
        |> Map.get("content_type")
        |> String.starts_with?("image")
      end)
      |> Enum.map(fn att -> Map.get(att, "url") end)

    delay = if Enum.empty?(attachment_urls) do
      0
    else
      5_000
    end


    case with_conversation(channel_name, channel_id, state) do
      {:ok, conversation} ->
        Lobber.Conversation.add_message(
          conversation,
          self(),
          {content, attachment_urls},
          %{channel_id: channel_id},
          delay: delay
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
  def handle_cast(:force_reconnect, state) do
    {:noreply, reconnect(state)}
  end

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

  def force_reconnect(pid) do
    GenServer.cast(pid, :force_reconnect)
  end
end
