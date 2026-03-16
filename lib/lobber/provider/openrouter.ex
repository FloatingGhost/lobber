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

  def prompt([], s) when is_binary(s) do
    prompt(
      [
        %{
          role: "system",
          content: @system
        }
      ],
      s
    )
  end

  def prompt(previous_messages, s) when is_binary(s) do
    {:ok, messages} =
      Jason.encode(%{
        messages:
          previous_messages ++
            [
              %{
                role: "user",
                content: s
              }
            ],
        model: model(),
        tools: Lobber.Tools.format()
      })

    Tesla.post(client(), "/api/v1/chat/completions", messages)
    |> handle_resp(previous_messages)
  end

  def prompt(previous_messages, %{tool_call_id: _} = s) do
    previous_messages = previous_messages ++ [s]

    {:ok, messages} =
      Jason.encode(%{
        messages: previous_messages,
        model: model(),
        tools: Lobber.Tools.format()
      })

    Tesla.post(client(), "/api/v1/chat/completions", messages)
    |> handle_resp(previous_messages)
  end

  defp handle_resp({:ok, %Tesla.Env{status: 200, body: body}}, previous_messages) do
    %{"choices" => [choice]} = body
    handle_message(previous_messages, choice)
  end

  defp handle_resp(_previous_messages, {:error, :timeout}) do
    Logger.error("Openrouter timed out!")
    :error
  end

  defp handle_message(chain, %{"finish_reason" => "stop", "message" => message}) do
    message
  end

  defp handle_message(previous_messages, %{
         "finish_reason" => "tool_calls",
         "message" => %{"tool_calls" => [call]} = message
       }) do
    %{"id" => tool_call_id, "function" => %{"name" => tool_name, "arguments" => args}} = call
    Logger.info("Running #{tool_name}(#{args})")

    tool = Lobber.Tools.by_name(tool_name)

    args
    |> tool.run()
    |> handle_tool_output(tool_call_id, previous_messages ++ [message])
  end

  defp handle_tool_output({:string, string}, tool_call_id, messages) when is_binary(string) do
    tool_use = %{
      role: "tool",
      tool_call_id: tool_call_id,
      content: "The tool has returned BEEEEEEP"
    }

    prompt(messages, tool_use)
  end
end
