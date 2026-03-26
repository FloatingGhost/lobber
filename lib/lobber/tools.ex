defmodule Lobber.Tools do
  alias Lobber.Tools

  def list() do
    ([
       Tools.AddTool,
       Tools.Remember,
       Tools.Store,
       Tools.SearchWeb,
       Tools.SummariseWeb,
       Tools.FetchWeb,
       Tools.AddIdentity,
       Tools.ReplaceIdentity,
       Tools.ProposeTool
     ] ++ list_by_behaviour())
    |> Enum.uniq()
  end

  # some tools (custom ones) are dynamic and won't be here at compile time
  defp list_by_behaviour() do
    for {module, _} <- :code.all_loaded(),
        Lobber.Tool.Behaviour in (module.module_info(:attributes)[:behaviour] || []) do
      module
    end
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
