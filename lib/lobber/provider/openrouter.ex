defmodule Lobber.Provider.OpenRouter do
  @behaviour Lobber.Provider.Behaviour

  require Logger

  @openrouter "https://openrouter.ai"

  @system File.read!("priv/SYSTEM.md")

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
        %{
          role: "system",
          content: @system
        }
      ],
      user_prompt,
      tools
    )
  end

  def prompt(previous_messages, user_prompt, tools \\ [Lobber.Tools.AddTool])
      when is_binary(user_prompt) do
    {:ok, messages} =
      Jason.encode(%{
        messages:
          previous_messages ++
            [
              %{
                role: "user",
                content: user_prompt
              }
            ],
        model: model(),
        tools: Lobber.Tools.format(tools)
      })

    Tesla.post(client(), "/api/v1/chat/completions", messages)
    |> handle_resp(previous_messages, tools)
  end

  def prompt(previous_messages, %{tool_call_id: _} = s, tools) do
    previous_messages = previous_messages ++ [s]

    {:ok, messages} =
      Jason.encode(%{
        messages: previous_messages,
        model: model(),
        tools: Lobber.Tools.format(tools)
      })

    Tesla.post(client(), "/api/v1/chat/completions", messages)
    |> handle_resp(previous_messages, tools)
  end

  defp handle_resp({:ok, %Tesla.Env{status: 200, body: body}}, previous_messages, tools) do
    %{"choices" => [choice]} = body
    handle_message(previous_messages, choice, tools)
  end

  defp handle_resp(_previous_messages, {:error, :timeout}, _) do
    Logger.error("Openrouter timed out!")
    :error
  end

  defp handle_message(chain, %{"finish_reason" => "stop", "message" => message}, _) do
    message
  end

  defp handle_message(
         previous_messages,
         %{
           "finish_reason" => "tool_calls",
           "message" => %{"tool_calls" => [call]} = message
         },
         tools
       ) do
    %{"id" => tool_call_id, "function" => %{"name" => tool_name, "arguments" => args}} = call
    Logger.info("Running #{tool_name}(#{args})")

    Lobber.Tools.run(tool_name, args)
    |> handle_tool_output(tool_call_id, previous_messages ++ [message], tools)
  end

  defp handle_tool_output({:string, string}, tool_call_id, messages, tools)
       when is_binary(string) do
    tool_use = %{
      role: "tool",
      tool_call_id: tool_call_id,
      content: string,
    }

    prompt(messages, tool_use, tools)
  end

  defp handle_tool_output({:add_tool, tool_name}, tool_call_id, messages, tools)
       when is_binary(tool_name) do


    to_add = Lobber.Tools.by_name(tool_name)

    response = if is_nil(to_add) do
      "The tool #{tool_name} doesn't exist!"
    else
      "The tool has been added to your context. You can use it now."
    end

    tools = if is_nil(to_add) do
      tools
    else
      [to_add | tools]
    end

    tool_use = %{
      role: "tool",
      tool_call_id: tool_call_id,
      content: response
    }

    prompt(messages, tool_use, tools)
  end
end
