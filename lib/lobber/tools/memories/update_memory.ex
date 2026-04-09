defmodule Lobber.Tools.UpdateMemory do
  @moduledoc false
  @behaviour Lobber.Tool.Behaviour

  def name(), do: "update_memory"

  def description(),
    do: """
    Update an existing memory by its ID.
    This replaces the old memory content with new content. Good for fixing mistakes!
    The updated memory will retain the same ID, so you don't need to re-list them!
    """

  def parameters(),
    do: %{
      memory_id: %{
        type: "string",
        description: "The ID of the memory to update"
      },
      new_content: %{
        type: "string",
        description: "The new content to replace the old memory"
      }
    }

  def run(%{"memory_id" => memory_id, "new_content" => new_content}) do
    case Lobber.Cave.update_memory(memory_id, new_content) do
      {:ok, _} ->
        {:ok, new} = Lobber.Cave.list_memories()
        {:string, "Memory ##{memory_id} updated!\nYour memories are now: \n#{new}"}

      {:error, :not_found, _} ->
        {:string, "Memory ##{memory_id} not found! Use list_memories to see valid IDs."}

      {:error, reason} ->
        {:string, "Error updating memory: #{reason}"}
    end
  end
end
