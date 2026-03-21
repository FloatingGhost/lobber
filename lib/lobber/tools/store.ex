defmodule Lobber.Tools.Store do
  @behaviour Lobber.Tool.Behaviour

  def name(), do: "store_shiny"

  def description(),
    do:
      "Store larger chunks of information for use later as a shiny. Use a descriptive filename to help you recall, or
      use the remember tool to keep a map between shiny name and its purpose"

  def parameters(),
    do: %{
      shiny_name: %{
        type: "string"
      },
      content: %{
        type: "string"
      }
    }

  def run(%{"shiny_name" => name, "content" => content}) do
    :ok = Lobber.Cave.store(name, content)
    {:string, "Your shiny has been stored as #{name}"}
  end
end
