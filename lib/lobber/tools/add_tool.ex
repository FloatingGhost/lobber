defmodule Lobber.Tools.AddTool do
  @behaviour Lobber.Tool.Behaviour

  def name(), do: "add_tool"

  def description(), do: "Add a tool to your context"

  def parameters(),
    do: %{
      name: %{
        type: "string"
      }
    }

  def run(%{"name" => name}), do: {:add_tool, name}
end
