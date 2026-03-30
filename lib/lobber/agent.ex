defmodule Lobber.Agent do
  @moduledoc """
  The 'agentic loop' of lobber
  An async task is spawned from a Conversation, which handles the latest
  message from the user.

  This loop will use the user's input to prompt the Provider with the new information,
  then handle the response, returning a binary representing the providers' response
  once the loop has finished
  """

  @supervisor Lobber.Agent.Supervisor
  @max_turns 50

  @starting_tools [
    Lobber.Tools.AddTool,
    Lobber.Tools.Remember,
    Lobber.Tools.UpdateMemory,
    Lobber.Tools.RemoveMemory,
    Lobber.Tools.ListMemories,
    Lobber.Tools.SummariseWeb,
    Lobber.Tools.SearchWeb,
    Lobber.Tools.FetchWeb,
    Lobber.Tools.AddIdentity,
    Lobber.Tools.ReplaceIdentity,
    Lobber.Tools.ProposeTool,
    Lobber.Tools.ViewSource,
    Lobber.Tools.ListModules,
    Lobber.Tools.ProposeModule
  ]

  alias Lobber.Conversation

  def supervisor(), do: @supervisor

  @doc """
  Request an agent to handle the given message.

  opts is an opaque term of implementation details. store your channel context
  in here that the agent doesn't need to care about. it'll be given back at the end.

  respond_to should be the genserver pid you expect the response to be sent to,
  it will be sent either {:agent_response, binary(), term()} or  {:agent_error, term(), term()}
  where the final element is your opts from invocation.
  """
  @spec prompt(pid(), list(map()), map(), map()) :: {:ok, pid()}
  def prompt(respond_to, [], next_message, opts) do
    # inject the system prompt before we start the loop proper
    system = %Conversation.Message{
      role: "system",
      content: Lobber.System.system_prompt()
    }

    prompt(respond_to, [system], next_message, opts)
  end

  def prompt(respond_to, messages, next_message, opts) do
    starting_tools = Map.get(opts, :starting_tools, @starting_tools)

    Task.Supervisor.start_child(supervisor(), fn ->
      case call_provider(messages, next_message, starting_tools, %{
             respond_to: respond_to,
             turns: 0
           }) do
        {:ok, text} ->
          GenServer.cast(respond_to, {:agent_response, text, opts})

        {:error, err} ->
          GenServer.cast(respond_to, {:agent_error, err, opts})
      end
    end)
  end

  # the main "agentic loop" (but it's not a loop because this is elixir)
  # agentic recursion?
  # handle_provider_response can either recurse back here, or exit out
  @spec call_provider(list(map()), map(), list(map()), map()) ::
          {:ok, binary()} | {:error, term()}
  defp call_provider(_messages, _next_message, _tools, %{turns: @max_turns}) do
    {:error, :too_many_turns}
  end

  defp call_provider(messages, next_message, tools, %{turns: turns} = opts) do
    Lobber.Provider.prompt(messages, next_message, tools)
    |> handle_provider_response(messages, tools, %{opts | turns: turns + 1})
  end

  # maybe the provider has finished
  defp handle_provider_response(%Conversation.Message{} = response, _messages, _tools, _opts) do
    {:ok, response}
  end

  # maybe the provider has requested we use a tool
  defp handle_provider_response(
         {:tools, invocations, history},
         _messages,
         tools,
         %{respond_to: respond_to} = opts
       ) do
    last_message = List.last(history)

    GenServer.cast(respond_to, {:intermediate_message, last_message})

    # the provider wants a tool(s) run
    # this can return lots of things, so let's let it mutate the history
    # tools may also have been added as a byproduct, so we need to reassign that
    {last_message, history, tools} = run_tools(last_message, history, tools, invocations, opts)

    call_provider(history, last_message, tools, opts)
  end

  defp run_tools(last_message, history, tools, [], opts) do
    {last_message, history, tools}
  end

  defp run_tools(
         last_message,
         message_list,
         tools,
         [%Lobber.Conversation.ToolCall{} = tool_call | invocations],
         opts
       ) do
    case Lobber.Tools.run(tool_call) |> handle_tool_output(tool_call.id, tools, opts) do
      {:tool_resp, response} ->
        run_tools(response, message_list ++ [last_message], tools, invocations, opts)

      {:tool_resp, response, new_tools} ->
        run_tools(response, message_list ++ [last_message], new_tools, invocations, opts)
    end
  end

  # then when our tool has been run, we want to send it back to the provider
  defp handle_tool_output(
         {:string, string},
         tool_call_id,
         tools,
         %{respond_to: respond_to} = opts
       )
       when is_binary(string) do
    tool_use = %Conversation.Message{
      role: "tool",
      tool_call_id: tool_call_id,
      content: string
    }

    GenServer.cast(respond_to, {:intermediate_message, tool_use})

    {:tool_resp, tool_use}
  end

  defp handle_tool_output(
         {:add_tool, tool_name},
         tool_call_id,
         tools,
         %{respond_to: respond_to} = opts
       )
       when is_binary(tool_name) do
    to_add = Lobber.Tools.by_name(tool_name)

    response =
      if is_nil(to_add) do
        "The tool #{tool_name} doesn't exist!"
      else
        "The tool has been added to your context. You can use it now."
      end

    tools =
      if is_nil(to_add) do
        tools
      else
        [to_add | tools]
      end
      |> Enum.uniq()

    tool_use = %Conversation.Message{
      role: "tool",
      tool_call_id: tool_call_id,
      content: response
    }

    GenServer.cast(respond_to, {:intermediate_message, tool_use})

    {:tool_resp, tool_use, tools}
  end
end
