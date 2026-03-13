defmodule Lobber.Discord do
  use GenServer
  require Logger

  @discord "https://discord.com"
  @heartbeat_ack_timeout 10_000

  @opcodes %{
    dispatch: 0,
    heartbeat: 1,
    identify: 2,
    presence: 3,
    voice_state: 4,
    resume: 6,
    reconnect: 7,
    request_guild_members: 8,
    invalid_session: 9,
    hello: 10,
    heartbeat_ACK: 11,
    request_soundboard_sounds: 31
  }

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  defp bot_token do
    Application.get_env(:lobber, :discord_bot_token)
  end

  defp opcode(human) do
    if Map.has_key?(@opcodes, human) do
      Map.get(@opcodes, human)
    else
      -1
    end
  end

  defp human(opcode) do
    h = Enum.find(@opcodes, fn {k, v} -> v == opcode end)

    if is_nil(h) do
      "Unknown Opcode"
    else
      {k, _} = h
      k
    end
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
        {Tesla.Middleware.Headers, headers()},
        Tesla.Middleware.JSON
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
       session_id: nil
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
    Logger.info("Sending heartbeat #{seq}")
    {:ok, hb_frame} = Jason.encode(%{"op" => opcode(:heartbeat), "d" => seq})

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
    {:ok, data} = Jason.decode(frame)
    %{"op" => op} = data
    Logger.info("Recieved #{human(op)} message")
    handle_data(data, state)
  end

  defp handle_data(
         %{
           "op" => 0,
           "s" => seq,
           "t" => "READY",
           "d" => %{"user" => %{"username" => username}}
         } = message,
         state
       ) do
    Logger.info("Discord is ready, hello #{username} (seq: #{seq})!")

    %{
      "d" => %{
        "resume_gateway_url" => resume_url,
        "session_id" => session_id
      }
    } = message

    %{state | sequence_number: seq, resume_url: resume_url, session_id: session_id}
  end

  defp handle_data(
         %{
           "op" => 0,
           "s" => seq,
           "t" => "RESUMED"
         },
         state
       ) do
    Logger.info("Discord resumed (seq: #{seq})!")

    %{state | sequence_number: seq}
  end

  defp handle_data(
         %{
           "op" => 0,
           "s" => seq,
           "t" => "GUILD_CREATE",
           "d" => data
         } = message,
         state
       ) do
    Logger.info("GUILD_CREATE")
    IO.inspect(data, limit: :infinity)

    %{state | sequence_number: seq}
  end

  defp handle_data(
         %{
           "op" => 0,
           "s" => seq,
           "t" => "MESSAGE_CREATE",
           "d" => %{
             "author" => %{"username" => username},
             "content" => content
           }
         } = message,
         state
       ) do
    Logger.info("#{username}: #{content}")
    %{state | sequence_number: seq}
  end

  defp handle_data(
         %{
           "op" => 0,
           "s" => seq,
           "t" => type,
           "d" => data
         },
         state
       ) do
    Logger.info("Message type #{type}")
    IO.inspect(data)

    %{state | sequence_number: seq}
  end

  defp handle_data(
         %{
           "op" => 10,
           "s" => sequence_number,
           "d" => %{
             "heartbeat_interval" => heartbeat
           }
         },
         state
       ) do
    Logger.info("HELLO recieved! Interval #{heartbeat}, seq: #{sequence_number}")
    hb_in = next_heartbeat(heartbeat)
    Process.send_after(self(), :heartbeat, hb_in)

    # now we've been welcomed, we need to identify ourselves
    if is_nil(state.session_id) do
      {:ok, handshake_frame} =
        Jason.encode(%{
          "op" => opcode(:identify),
          "d" => %{
            "token" => bot_token(),
            "properties" => %{
              "os" => "Linux",
              "browser" => "YuiBot",
              "device" => "YuiBot"
            },
            "presence" => %{
              "activities" => [],
              "status" => "online"
            },
            "intents" => 4096
          }
        })

      :ok = :gun.ws_send(state.conn, state.ref, {:text, handshake_frame})

      %{
        state
        | heartbeat_interval: heartbeat,
          sequence_number: sequence_number
      }
    else
      # resume time
      Logger.info("Resuming session")

      {:ok, resume_frame} =
        Jason.encode(%{
          "op" => opcode(:resume),
          "d" => %{
            "token" => bot_token(),
            "session_id" => state.session_id,
            "seq" => state.sequence_number
          }
        })

      :ok = :gun.ws_send(state.conn, state.ref, {:text, resume_frame})

      %{
        state
        | heartbeat_interval: heartbeat,
          sequence_number: sequence_number
      }
    end
  end

  defp handle_data(
         %{
           "op" => 11
         },
         %{heartbeat_interval: heartbeat} = state
       ) do
    # Heartbeat response. Schedule the next heartbeat
    Logger.info("Heartbeat response recieved, scheduling next (interval: #{heartbeat})")
    next_hb = next_heartbeat(heartbeat)
    Process.send_after(self(), :heartbeat, next_hb)
    %{state | heartbeat_acknowledged: true}
  end
end
