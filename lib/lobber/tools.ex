defmodule Lobber.Tools do
  def list() do
    [
      Lobber.Tools.AddTool,
      Lobber.Tools.Remember,
      Lobber.Tools.Store,
      Lobber.Tools.SearchWeb,
      Lobber.Tools.SummariseWeb
    ]
  end

  def as_text() do
    list()
    |> Enum.map(fn mod -> "TOOL #{mod.name()} - #{mod.description()}" end)
    |> Enum.join("\n")
  end

  def format(tools) do
    tools
    |> Enum.map(fn mod ->
      %{
        type: "function",
        function: %{
          name: mod.name(),
          description: mod.description(),
          parameters: mod.parameters()
        }
      }
    end)
  end

  def by_name(name) do
    list()
    |> Enum.find(fn mod -> mod.name() == name end)
  end

  def run(%Lobber.Conversation.ToolCall{} = call) do
    by_name(call.name).run(call.arguments)
  end
end
