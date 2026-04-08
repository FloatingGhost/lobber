defmodule Lobber.Tools.UpdateMemory do
  @moduledoc false
  @behaviour Lobber.Tool.Behaviour

  def name(), do: "update_memory"

  def description(),
    do: """
    Update an existing memory by its ID. Use list_memories to see all memory IDs first.
    This replaces the old memory content with new content. Good for fixing mistakes!
    """

  def parameters(),
    do: %{
      memory_id: %{
        type: "string",
        description: "The ID of the memory to update (from list_memories)"
      },
      new_content: %{
        type: "string",
        description: "The new content to replace the old memory"
      }
    }

  def run(%{"memory_id" => memory_id, "new_content" => new_content}) do
    case Lobber.Cave.update_memory(memory_id, new_content) do
      :ok ->
        {:string, "Memory ##{memory_id} updated! Lobber remember new version now."}

      {:error, :not_found} ->
        {:string, "Memory ##{memory_id} not found! Use list_memories to see valid IDs."}

      {:error, reason} ->
        {:string, "Error updating memory: #{reason}"}
    end
  end
end
