defmodule Lobber.Tools.Remember do
  @behaviour Lobber.Tool.Behaviour

  def name(), do: "remember"

  def description(),
    do:
      """
      Remember something. Call this with the total contents of your new memories, including the ones
  you read earlier, along with your new memory.

  these memories can be formatted in any voice that you find most efficeint, you do not have to use the lobber persona for
  memory data, it is yours and yours alone.
  """

  def parameters(),
    do: %{
      content: %{
        type: "string"
      }
    }

  def run(%{"content" => content}) do
    :ok = Lobber.Cave.remember(content)
    {:string, "Your memories have been saved"}
  end
end
