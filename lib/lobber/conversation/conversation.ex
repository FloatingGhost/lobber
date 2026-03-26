defmodule Lobber.Conversation do
  alias Lobber.Conversation.Message

  use GenServer
  require Logger

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    {id, _opts} = Keyword.pop(opts, :id)

    # maybe reload when we start
    history =
      Lobber.Cave.read_backup(id)
      |> maybe_inject_system_prompt()

    GenServer.start_link(
      __MODULE__,
      %{
        history: history,
        id: id
      },
      name: name
    )
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  defp maybe_inject_system_prompt([%Message{role: "system"} | rest] = history) do
    # replace prompt with the latest version
    maybe_inject_system_prompt(rest)
  end

  defp maybe_inject_system_prompt(history) do
    system = %Message{
      role: "system",
      content: Lobber.System.system_prompt()
    }

    [system | history]
  end

  @impl true
  def handle_cast(
        {:message, respond_to, "!!" <> command, opts},
        state
      ) do
    Logger.info("COMMAND: #{command}")

    handle_command(command, state, %{respond_to: respond_to, channel_opts: opts})
  end

  @impl true
  def handle_cast({:message, respond_to, message, opts}, %{id: id, history: history} = state) do
    Logger.info("Message: #{message}")

    message = %Message{
      role: "user",
      content: message
    }

    # wrap opts in our own layer so we know who to respond to
    opts = %{
      respond_to: respond_to,
      channel_opts: opts
    }

    # spin off an async task to handle the actual processing
    Lobber.Agent.prompt(self(), history, message, opts)

    {:noreply, %{state | history: concat_and_backup_messages(id, history, message)}}
  end

  @impl true
  def handle_cast(
        {:agent_response, %Message{} = message, opts},
        %{id: id, history: history} = state
      ) do
    %{respond_to: respond_to, channel_opts: channel_opts} = opts

    GenServer.cast(respond_to, {:conversation_response, message, channel_opts})
    {:noreply, %{state | history: concat_and_backup_messages(id, history, message)}}
  end

  @impl true
  def handle_cast(
        {:intermediate_message, %Message{} = message},
        %{id: id, history: history} = state
      ) do
    {:noreply, %{state | history: concat_and_backup_messages(id, history, message)}}
  end

  def concat_messages(history, %Message{} = next) do
    history ++ [next]
  end

  defp concat_and_backup_messages(id, history, next) do
    concat = concat_messages(history, next)
    Lobber.Cave.backup_conversation(id, concat)
    concat
  end

  defp handle_command("reload", %{id: id, history: history} = state, opts) do
    Lobber.Cave.reload()
    history = maybe_inject_system_prompt(history)
    Lobber.Cave.backup_conversation(id, history)
    command_response("Conversation reloaded", %{state | history: history}, opts)
  end

  defp handle_command("clear", %{id: id} = state, opts) do
    history = maybe_inject_system_prompt([])
    Lobber.Cave.backup_conversation(id, history)
    command_response("Conversation cleared", %{state | history: history}, opts)
  end

  defp handle_command("promote" <> mod, state, opts) do
    mod
    |> String.trim()
    |> Lobber.Cave.promote_tool()

    command_response("#{mod} promoted.", state, opts)
  end

  defp handle_command(cmd, state, opts) do
    command_response("What is #{cmd}????", state, opts)
  end

  defp command_response(output, state, opts) do
    message = %Message{
      role: "system",
      content: output
    }

    %{respond_to: respond_to, channel_opts: channel_opts} = opts
    GenServer.cast(respond_to, {:conversation_response, message, channel_opts})
    {:noreply, state}
  end

  # api to conversation
  @doc """
  Add a message to a conversation
  Will process the message given, then respond to the given pid
  """
  def add_message(conversation_pid, respond_to, message, opts) do
    GenServer.cast(conversation_pid, {:message, respond_to, message, opts})
  end
end
