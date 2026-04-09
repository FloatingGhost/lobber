defmodule Lobber.Tools.ListMemories do
  @moduledoc false
  @behaviour Lobber.Tool.Behaviour

  def name(), do: "list_memories"

  def description(),
    do: """
    List all memories with their IDs. Memories are stored as structured entries with unique identifiers.
    This helps keep track of what Lobber remembers and allows for management of memory entries.
    You should not need to use this most of the time, your latest memories are usually in your system prompt.
    However this will provide the latest version, should you need them.
    """

  def parameters(), do: nil

  def run(_args) do
    mem = Lobber.Cave.memories()
    {:string, mem}
  end
end
