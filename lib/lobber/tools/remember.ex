defmodule Lobber.Tools.Remember do
  @moduledoc false
  @behaviour Lobber.Tool.Behaviour

  def name(), do: "remember"

  def description(),
    do: """
        Remember something. Call this with what you want to remember, and the memory will be appended to your memory file

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
