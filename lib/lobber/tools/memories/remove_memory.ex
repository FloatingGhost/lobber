defmodule Lobber.Tools.RemoveMemories do
  @moduledoc false
  @behaviour Lobber.Tool.Behaviour

  def name(), do: "remove_memories"

  def description(),
    do: """
    Remove one or more memories by their ID.
    Memories each have a nanoID at the start of their line, this is the ID you should use.
    This helps keep Lobber's cave organized!
    The updated list of memories will be returned by this tool.
    """

  def parameters(),
    do: %{
      memory_ids: %{
        type: "array",
        items: %{
          type: "string"
        },
        description: "A list of ids remove from memories (from list_memories)"
      }
    }

  def run(%{"memory_ids" => memory_ids}) when is_binary(memory_ids) do
    # The model is being a moron
    {:ok, memory_ids} = Jason.decode(memory_ids)
    run(%{"memory_ids" => memory_ids})
  end

  def run(%{"memory_ids" => memory_ids}) when is_list(memory_ids) do
    case Lobber.Cave.remove_memories(memory_ids) do
      :ok ->
        new = Lobber.Cave.memories()

        {:string,
         "Memories #{Enum.join(memory_ids, ", ")} removed from cave! Lobber forget those ones. \n#{new}"}

      {:error, reason} ->
        {:string, "Error removing memory: #{reason}"}
    end
  end
end
