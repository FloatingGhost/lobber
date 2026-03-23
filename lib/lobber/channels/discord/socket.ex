defmodule Lobber.Discord.Socket do
  use GenServer

  require Logger

  alias Lobber.Discord.DiscordMessage
  alias Lobber.Conversation

  @behaviour Lobber.Channel.Behaviour

  @discord "https://discord.com"
  @heartbeat_ack_timeout 10_000

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl true
  def name(), do: "discord"

  defp bot_token do
    Application.get_env(:lobber, :discord_bot_token)
  end

  defp headers do
    [
      {"user-agent", "YuiBot (application 182675940042735616)"},
      {"authorization", "Bot #{bot_token()}"}
    ]
  end

  @impl true
  def init(_state) do
    Logger.info("Starting discord...")

    client =
      Tesla.client([
        {Tesla.Middleware.BaseUrl, @discord},
        {Tesla.Middleware.Headers, [{"content-type", "application/json"} | headers()]},
        Tesla.Middleware.JSON,
        {Tesla.Middleware.Timeout, timeout: 10_000}
      ])

    %{"url" => websock_url} = Tesla.get!(client, "/api/gateway/bot").body

    Logger.info("Connecting to #{websock_url}")
    websock_url = URI.parse(websock_url)

    Logger.info("Initiating connection to #{websock_url.host}")
    {:ok, conn} = :gun.open(to_charlist(websock_url.host), 443, %{protocols: [:http]})
    Logger.info("Connection established")

    {:ok,
     %{
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

  defp next_heartbeat(interval) do
    (interval * :rand.uniform())
    |> floor()
  end

  @impl true
  def handle_info({:gun_up, _pid, _opts}, %{status: :connecting, conn: conn} = state) do
    Logger.info("Upgrading to websocket")
    ref = :gun.ws_upgrade(conn, "/?v=10&encoding=json", headers())

    {
      :noreply,
      %{state | status: :upgrading, ref: ref}
    }
  end

  @impl true
  def handle_info({:gun_upgrade, _pid, _ref, _, _}, %{status: :upgrading} = state) do
    Logger.info("Upgraded")

    {
      :noreply,
      %{state | status: :connected}
    }
  end

  @impl true
  def handle_info(message, %{status: :upgrading} = state) do
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
    Logger.info("Sending heartbeat #{seq}")

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
        %{
          heartbeat_acknowledged: false,
          resume_url: websock_url,
          conn: conn,
          ref: ref
        } = state
      ) do
    Logger.info("oops! Heartbeat was not acknowledged. We have to reconnect...")

    :ok = :gun.shutdown(conn)

    websock_url = URI.parse(websock_url)

    Logger.info("Initiating connection to #{websock_url.host}")
    {:ok, conn} = :gun.open(to_charlist(websock_url.host), 443, %{protocols: [:http]})
    Logger.info("Connection established")

    {:noreply,
     %{
       state
       | conn: conn,
         ref: ref,
         status: :connecting
     }}
  end

  def handle_info(
        :heartbeat_ack_check,
        %{heartbeat_acknowledged: true} = state
      ) do
    Logger.info("We're good")
    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_ws, _pid, _ref, frame}, %{status: :connected} = state) do
    {:noreply, handle_frame(frame, state)}
  end

  def handle_info(other, state) do
    Logger.info("Weird state!")
    IO.inspect(other)
    IO.inspect(state)
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
    Logger.info("Discord is ready, hello #{username}!")

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
           data:
             %{
               "author" => %{"username" => username, "id" => id},
               "content" => content,
               "channel_id" => channel_id
             } = data
         } = message,
         %{client: client, user_id: user_id} = state
       ) do
    Logger.info("#{username}: #{content}")
    conversation = Lobber.Conversations.get_or_spawn(name(), channel_id)

    Lobber.Conversation.add_message(
      conversation,
      self(),
      content,
      %{channel_id: channel_id}
    )

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
    Logger.info("HELLO recieved! Interval #{heartbeat}")
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
      Logger.info("Resuming session")

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
    Logger.info("Heartbeat response recieved, scheduling next (interval: #{heartbeat})")
    next_hb = next_heartbeat(heartbeat)
    Process.send_after(self(), :heartbeat, next_hb)
    %{state | heartbeat_acknowledged: true}
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
end
