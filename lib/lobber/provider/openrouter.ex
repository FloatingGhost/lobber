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
      Tesla.Middleware.Logger,
      {Tesla.Middleware.Retry, delay: 500, max_retries: 5, max_delay: 4_000},
      {Tesla.Middleware.Timeout, timeout: :infinity},
      {Tesla.Middleware.BaseUrl, @openrouter},
      {Tesla.Middleware.Headers, headers()},
      Tesla.Middleware.JSON
    ])
  end

  def prompt(history, %Conversation.Message{} = s, tools) do
    history = Conversation.concat_messages(history, s)

    {:ok, messages} =
      Jason.encode(%{
        messages: history,
        model: model(),
        provider: %{
          sort: %{
            by: "throughput"
          }
        },
        tools: Lobber.Tools.format(tools)
      })

    IO

    Tesla.post(client(), "/api/v1/chat/completions", messages)
    |> handle_resp(history, tools)
  end

  defp handle_resp({:ok, %Tesla.Env{status: 200, body: %{"choices" => [choice]}}}, history, tools) do
    handle_message(history, choice, tools)
  end

  defp handle_resp({:ok, %Tesla.Env{status: 400, body: body}}, _, _) do
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
    history = Conversation.concat_messages(history, message)
    [tool_use] = message.tool_calls

    {:tool, tool_use}
  end
end
