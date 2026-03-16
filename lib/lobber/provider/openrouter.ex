defmodule Lobber.Provider.OpenRouter do
  @behaviour Lobber.Provider.Behaviour

  alias Lobber.Conversation

  require Logger

  @openrouter "https://openrouter.ai"

  defp model do
    Application.get_env(:lobber, :model_id)
  end

  defp api_key do
    Application.get_env(:lobber, :openrouter_api_key)
  end

  defp headers do
    [
      {"authorization", "Bearer #{api_key()}"}
    ]
  end

  def client do
    Tesla.client([
      {Tesla.Middleware.Timeout, timeout: :infinity},
      {Tesla.Middleware.BaseUrl, @openrouter},
      {Tesla.Middleware.Headers, headers()},
      Tesla.Middleware.JSON
    ])
  end

  def prompt([], user_prompt, tools) when is_binary(user_prompt) do
    prompt(
      [
        %Conversation.Message{
          role: "system",
          content: Lobber.System.system_prompt()
        }
      ],
      user_prompt,
      tools
    )
  end

  def prompt(
        history,
        user_prompt,
        tools \\ [Lobber.Tools.AddTool, Lobber.Tools.Remember]
      )

  def prompt(history, user_prompt, tools)
      when is_binary(user_prompt) do
    {:ok, messages} =
      Jason.encode(%{
        messages:
          Conversation.add_message(history, %Conversation.Message{
            role: "user",
            content: user_prompt
          }),
        model: model(),
        tools: Lobber.Tools.format(tools)
      })

    IO.inspect(messages)
    Tesla.post(client(), "/api/v1/chat/completions", messages)
    |> handle_resp(history, tools)
  end

  def prompt(history, %Conversation.Message{tool_call_id: _} = s, tools) do
    history = Conversation.add_message(history, s)

    {:ok, messages} =
      Jason.encode(%{
        messages: history,
        model: model(),
        tools: Lobber.Tools.format(tools)
      })

    Tesla.post(client(), "/api/v1/chat/completions", messages)
    |> handle_resp(history, tools)
  end

  defp handle_resp({:ok, %Tesla.Env{status: 200, body: %{"choices" => [choice]}}}, history, tools) do
    handle_message(history, choice, tools)
  end

  defp handle_resp({:ok, %Tesla.Env{status: 400, body: body}}) do
    IO.inspect(body)
    :error
  end

  defp handle_resp({:error, :timeout}, _history, _tools) do
    Logger.error("Openrouter timed out!")
    :error
  end

  defp handle_message(_history, %{"finish_reason" => "stop", "message" => message}, _) do
    message
    |> Conversation.Message.decode()
  end

  defp handle_message(
         history,
         %{
           "finish_reason" => "tool_calls",
           "message" => message
         },
         tools
       ) do
    message = Conversation.Message.decode(message)
    history = Conversation.add_message(history, message)
    [tool_use] = message.tool_calls

    Logger.info("Running #{tool_use.name}(#{Jason.encode!(tool_use.arguments)})")

    Lobber.Tools.run(tool_use)
    |> handle_tool_output(tool_use.id, history, tools)
  end

  defp handle_tool_output({:string, string}, tool_call_id, messages, tools)
       when is_binary(string) do
    tool_use = %Conversation.Message{
      role: "tool",
      tool_call_id: tool_call_id,
      content: string
    }

    prompt(messages, tool_use, tools)
  end

  defp handle_tool_output({:add_tool, tool_name}, tool_call_id, messages, tools)
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

    tool_use = %Conversation.Message{
      role: "tool",
      tool_call_id: tool_call_id,
      content: response
    }

    IO.inspect(tools)

    prompt(messages, tool_use, tools)
  end
end
