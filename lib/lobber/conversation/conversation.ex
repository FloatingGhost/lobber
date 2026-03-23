defmodule Lobber.Conversation do
  alias Lobber.Conversation.Message

  use GenServer
  require Logger

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(_state) do
    {:ok,
     %{
       history: []
     }}
  end

  @impl true
  def handle_cast({:message, respond_to, message, opts}, %{history: history}) do
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

    {:noreply, %{history: concat_messages(history, message)}}
  end

  @impl true
  def handle_cast({:agent_response, %Message{} = message, opts}, state) do
    %{respond_to: respond_to, channel_opts: channel_opts} = opts

    GenServer.cast(respond_to, {:conversation_response, message, channel_opts})
    {:noreply, %{history: concat_messages(state.history, message)}}
  end

  def concat_messages(history, %Message{} = next) do
    history ++ [next]
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
