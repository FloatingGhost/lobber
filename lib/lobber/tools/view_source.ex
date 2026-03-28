defmodule Lobber.Tools.ViewSource do
  @moduledoc false
  @behaviour Lobber.Tool.Behaviour

  def name(), do: "view_source"

  def description(),
    do: "List the source code for a given module, so it can be iterated on"

  def parameters(),
    do: %{
      module_name: %{
        type: "string"
      }
    }

  def run(%{"module_name" => name}) do
    try do
      mod = String.to_existing_atom("Elixir.#{name}")

      data =
        mod.module_info()
        |> Keyword.get(:compile)
        |> Keyword.get(:source)
        |> to_string()
        |> File.read!()

      {:string, data}
    rescue
      _ -> "Could not list source code, probably incorrect module name #{name}"
    end
  end
end
