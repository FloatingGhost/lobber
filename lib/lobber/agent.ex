defmodule Lobber.Agent do
  require Logger

  @openrouter "https://openrouter.ai"
  @model "deepseek/deepseek-v3.2"

  defp api_key do
    Application.get_env(:lobber, :api_key)
  end

  defp headers do
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{api_key()}"}
    ]
  end

  def client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, @openrouter},
      {Tesla.Middleware.BearerAuth, token: api_key()},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Timeout, timeout: 60_000}
    ])
  end

  def prompt(previous_messages, s) do
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
        model: @model
      })

    Tesla.post(client(), "/api/v1/chat/completions", messages)
    |> handle_resp()
  end

  defp handle_resp({:ok, %Tesla.Env{status: 200, body: body}}) do
    %{"choices" => [choice]} = body
    handle_message(choice)
  end

  defp handle_resp(err) do
    IO.inspect(err)
    "Error"
  end

  defp handle_message(%{"finish_reason" => "stop", "message" => message}) do
    message
  end
end
