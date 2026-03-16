defmodule Lobber.Tools do
  def list() do
    [
      Lobber.Tools.AddTool,
      Lobber.Tools.Remember
    ]
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
