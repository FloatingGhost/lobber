defmodule Lobber.Tools.ListModules do
  @moduledoc false
  @behaviour Lobber.Tool.Behaviour

  def name(), do: "list_modules"

  def description(),
    do: "List the source code for a given module, so it can be iterated on"

  def parameters(),
    do: nil

  def run(_) do
    mods =
      :code.all_loaded()
      |> Enum.filter(fn {mod, _} -> String.starts_with?(to_string(mod), "Elixir.Lobber") end)
      |> Enum.map_join(", ", fn {mod, _} -> to_string(mod) |> String.trim_leading("Elixir.") end)

    {:string, mods}
  end
end
