defmodule Lobber.Tools do
  @moduledoc """
  Utility functions for interacting with tools.
  Used as both a store to ensure tools are brought in by the compiler,
  as well as formatting for prompts
  """

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
       Tools.ProposeTool,
       Tools.ViewSource,
       Tools.ListModules,
       Tools.ProposeModule
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
    |> Enum.map_join("\n", fn mod -> "TOOL #{mod.name()} - #{mod.description()}" end)
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

  @spec by_name(binary()) :: atom() | nil
  def by_name(name) do
    list()
    |> Enum.find(fn mod -> mod.name() == name end)
  end

  def run(%Lobber.Conversation.ToolCall{} = call) do
    by_name(call.name).run(call.arguments)
  end
end
