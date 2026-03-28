defmodule Lobber.Tools.ProposeTool do
  @moduledoc false
  @behaviour Lobber.Tool.Behaviour

  def name(), do: "propose_tool"

  def description(),
    do:
      "Propose that a new tool be added to your modules. Read the 'Tool Module Proposition' skill
      to understand the process for creating a new tool"

  def parameters(),
    do: %{
      tool_name: %{
        type: "string"
      },
      source_code: %{
        type: "string"
      }
    }

  def run(%{"tool_name" => name, "source_code" => code}) do
    Lobber.Cave.store("tool-proposal-#{name}.ex", code)
    {:string, "Proposal stored as tool-proposal-#{name}.ex"}
  end
end
