defmodule Lobber.Tools.AddMemory do
  @moduledoc false
  @behaviour Lobber.Tool.Behaviour

  def name(), do: "add_memory"

  def description(),
    do: """
    Create a new memory. Call this with what you want to remember, and the memory will be appended to your memories, with a new ID.

    These memories can be formatted in any voice that you find most efficient, you do not have to use the lobber persona for
    memory data, it is yours and yours alone.

    You will be given your newly updated list of memories in the response.
    """

  def parameters(),
    do: %{
      content: %{
        type: "string"
      }
    }

  def run(%{"content" => content}) do
    :ok = Lobber.Cave.add_memory(content)
    new = Lobber.Cave.memories()
    {:string, "Your memory has been saved.\nYour memories are now:\n#{new}"}
  end
end
