defmodule Lobber.Tools.SummariseWeb do
  @behaviour Lobber.Tool.Behaviour

  def name(), do: "summarise_web"

  def description(),
    do:
      "Summarise information on the web with a given search term. Will return synthesised information about the topic."

  def parameters(),
    do: %{
      query: %{
        type: "string"
      }
    }

  def run(%{"query" => query}) do
    data = Lobber.Integrations.Perplexity.sonar(query)
    {:string, data}
  end
end
