defmodule Lobber.Tools do
  def list() do
    [
      Lobber.Tools.AddTool,
      Lobber.Tools.Text,
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

  def run(name, args) when is_binary(args) do
    case Jason.decode(args) do
      {:ok, args} -> by_name(name).run(args)
      _ -> :error
    end
  end
end
