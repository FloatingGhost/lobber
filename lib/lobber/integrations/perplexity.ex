defmodule Lobber.Integrations.Perplexity do
  @perplexity "https://api.perplexity.ai"

  defp api_key() do
    Lobber.Config.get(__MODULE__, :api_key)
  end

  defp model() do
    Lobber.Config.get(__MODULE__, :sonar_model)
  end

  defp headers do
    [
      {"authorization", "Bearer #{api_key()}"}
    ]
  end

  defp client do
    Tesla.client([
      Tesla.Middleware.Logger,
      {Tesla.Middleware.Retry, delay: 500, max_retries: 5, max_delay: 4_000},
      {Tesla.Middleware.Timeout, timeout: 120_000},
      {Tesla.Middleware.BaseUrl, @perplexity},
      {Tesla.Middleware.Headers, headers()},
      Tesla.Middleware.JSON
    ])
  end

  def search(query) do
    Tesla.post(client(), "/search", %{
      query: query,
      max_results: 5,
      max_tokens_per_page: 4096
    })
    |> handle_search()
  end

  defp handle_search({:ok, %Tesla.Env{status: 200, body: body}}) do
    %{"results" => results} = body

    results
    |> Enum.map_join("\n", fn %{
                                "title" => title,
                                "snippet" => snippet,
                                "url" => url,
                                "last_updated" => date
                              } ->
      """
      #{title} at #{date}, url: #{url}
        #{snippet}
      ---
      """
    end)
  end

  def sonar(query) do
    Tesla.post(client(), "/v1/sonar", %{
      model: model(),
      messages: [
        %{
          role: "user",
          content: query
        }
      ]
    })
    |> handle_sonar()
  end

  defp handle_sonar({:ok, %Tesla.Env{status: 200, body: body}}) do
    %{
      "choices" => choices,
      "citations" => citations
    } = body

    [%{"message" => %{"content" => content}}] = choices

    citations =
      citations
      |> Enum.with_index()
      |> Enum.map_join("\n", fn {cit, index} -> "[#{index}] #{cit}" end)

    """
    #{content}

    citations:
    #{citations}
    """
  end
end
