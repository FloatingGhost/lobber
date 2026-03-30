defmodule Lobber.Tools.RemoveMemory do
  @moduledoc false
  @behaviour Lobber.Tool.Behaviour

  def name(), do: "remove_memory"

  def description(),
    do: """
    Remove a memory by its ID. Use list_memories to see all memory IDs first.
    Memories are numbered starting from 1. This helps keep Lobber's cave organized!
    The update list of memories will be returned by this tool.
    """

  def parameters(),
    do: %{
      memory_id: %{
        type: "integer",
        description: "The ID of the memory to remove (from list_memories)"
      }
    }

  def run(%{"memory_id" => memory_id}) do
    case Lobber.Cave.remove_memory(memory_id) do
      :ok ->
        {:string, new_memories } = Lobber.Tools.ListMemories.run(nil)
        {:string, "Memory ##{memory_id} removed from cave! Lobber forget that one. \n#{new_memories}"}

      {:error, :not_found} ->
        {:string, "Memory ##{memory_id} not found! Use list_memories to see valid IDs."}

      {:error, reason} ->
        {:string, "Error removing memory: #{reason}"}
    end
  end
end
