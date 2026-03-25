defmodule Lobber.Tools.FetchWeb do
  @behaviour Lobber.Tool.Behaviour

  require Logger

  def name(), do: "fetch_web"

  def description(),
    do:
      "Fetch a single URL from the web and return its raw HTML. The URL should be a complete protocol, host and path.

      For example https://google.com"

  def parameters(),
    do: %{
      query: %{
        type: "string"
      }
    }

  def run(%{"query" => query}) do
    case Tesla.get(client(), query) do
      {:ok, %Tesla.Env{body: body}} ->
        {:string, body}

      {:ok, %Tesla.Env{status: status}} ->
        {:string, "Request errored with HTTP code #{status}"}

      other ->
        Logger.error("#{inspect(other)}")
        {:string, "Request could not be executed."}
    end
  end

  defp client do
    Tesla.client([
      Tesla.Middleware.Logger,
      {Tesla.Middleware.Retry, delay: 500, max_retries: 5, max_delay: 4_000},
      {Tesla.Middleware.Timeout, timeout: 120_000},
      Tesla.Middleware.JSON
    ])
  end
end
