defmodule Lobber.Tools.AddTool do
  @behaviour Lobber.Tool.Behaviour

  def name(), do: "add_tool"

  def description(), do: "Add a tool to your context.
  If you do not currently have access to a tool you require for your current task, you should call this tool with
  the name of the tool you want access to."

  def parameters(),
    do: %{
      name: %{
        type: "string"
      }
    }

  def run(%{"name" => name}), do: {:add_tool, name}
end
