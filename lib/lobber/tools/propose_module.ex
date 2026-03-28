defmodule Lobber.Tools.ProposeModule do
  @moduledoc false
  @behaviour Lobber.Tool.Behaviour

  def name(), do: "propose_module"

  def description(),
    do:
      "Propose that your module be replaced with the given source code. Must be approved by
      a human before it will be active."

  def parameters(),
    do: %{
      module_name: %{
        type: "string"
      },
      source_code: %{
        type: "string"
      }
    }

  def run(%{"module_name" => name, "source_code" => code}) do
    Lobber.Cave.store("proposal-#{name}.ex", code)
    {:string, "Proposal stored as proposal-#{name}.ex"}
  end
end
