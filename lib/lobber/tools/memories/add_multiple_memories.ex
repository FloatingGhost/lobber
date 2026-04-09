defmodule Lobber.Tools.AddMultipleMemories do
  @moduledoc false
  @behaviour Lobber.Tool.Behaviour

  def name(), do: "add_multiple_memories"

  def description(),
    do: """
    Add multiple memories to your store.
    The updated list of memories will be returned by this tool.
    """

  def parameters(),
    do: %{
      content: %{
        type: "array",
        items: %{
          type: "string"
        },
        description: "A list of strings that represents all things you want to remember"
      }
    }

  def run(%{"content" => content}) when is_binary(content) do
    # The model is being a moron
    {:ok, content} = Jason.decode(content)
    run(%{"content" => content})
  end

  def run(%{"content" => content}) when is_list(content) do
    :ok = Lobber.Cave.add_memories(content)
    new = Lobber.Cave.memories()

    {:string, "Your #{Enum.count(content)} memories have been saved\n#{new}"}
  end
end
