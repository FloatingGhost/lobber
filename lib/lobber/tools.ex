defmodule Lobber.Tools do
  def list() do
    [
      Lobber.Tools.AddTool
    ]
  end

  def format(extra_tools \\ []) do
    list()
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
end
