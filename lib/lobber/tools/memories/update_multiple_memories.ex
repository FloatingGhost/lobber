defmodule Lobber.Tools.UpdateMultipleMemories do
  @moduledoc false
  @behaviour Lobber.Tool.Behaviour

  def name(), do: "update_multiple_memories"

  def description(),
    do: """
    Update multiple memories in your store.
    This replaces the old memory content with new content. Good for fixing mistakes!
    The updated memory will retain the same ID, so you don't need to re-list them!
    """

  def parameters(),
    do: %{
      memories: %{
        type: "array",
        items: %{
          type: "object",
          properties: %{
            memory_id: %{
              type: "string",
              description: "The ID of the memory to update"
            },
            new_content: %{
              type: "string",
              description: "The new content to replace the old memory"
            }
          }
        },
        description: "A list of strings that represents all things you want to remember"
      }
    }

  def run(%{"memories" => memories}) when is_binary(memories) do
    # The model is being a moron
    {:ok, memories} = Jason.decode(memories)
    run(%{"memories" => memories})
  end

  def run(%{"memories" => memories}) when is_list(memories) do
    update_results =
      Lobber.Cave.update_memories(memories)
      |> Enum.map_join("\n", fn update_result ->
        case update_result do
          {:ok, memory_id} ->
            "Memory #{memory_id} updated!"

          {:error, :not_found, memory_id} ->
            "Memory #{memory_id} not found!"

          {:error, reason} ->
            "Error updating memory: #{reason}"
        end
      end)

    new = Lobber.Cave.memories()

    {:string, "#{update_results}\n#{new}"}
  end
end
