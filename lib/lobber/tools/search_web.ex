defmodule Lobber.Tools.SearchWeb do
  @moduledoc false
  @behaviour Lobber.Tool.Behaviour

  def name(), do: "search_web"

  def description(),
    do:
      "Search the web with a given search term. Will return unsummarised results for direct access."

  def parameters(),
    do: %{
      query: %{
        type: "string"
      }
    }

  def run(%{"query" => query}) do
    data = Lobber.Integrations.Perplexity.search(query)
    {:string, data}
  end
end
