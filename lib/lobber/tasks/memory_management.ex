defmodule Lobber.Tasks.MemoryManagement do
  @behaviour Lobber.Tasks.Behaviour

  require Logger

  defp prompt() do
    {:ok, memories} = Lobber.Cave.list_memories()

    """
    You are in a deep sleep and you are sorting through your memories.
    You should use this time to consider which memories are still important.

    You should remove memories that are:
    - too old to be relevent
    - older than contradictory memories
    - just not that useful to keep around, either low information or too specific to be useful

    You should reformat messages that were stored with extraneous information.

    Then, you should do the same with your identity - you will wake up knowing who you are better
    than you do now. Apply the same methodology and replace your identity with a new version if
    you deem it worthwhile.

    You will also be given recent conversations, which you may opt to save memories from at this point.

    Note! it is entirely valid for you to decide that memories and identity are fine as-is and leave them
    how they are.

    MEMORY TOOL INSTRUCTIONS:
    1. Reference the memories below as your starting memories
    2. Use update_memory (with memory_id) to MODIFY existing memories - NOT add_memory!
      - use update_multiple_memories if you want to alter more than one
    3. Use remove_memories (with memory_id list) to DELETE outdated entries
    4. Only use remember for genuinely NEW information not already in memories
    5. Do NOT combine everything into one mega-memory - keep memories focused.
    5. If you find a mega-memory with multiple topics, use add_memories to create a set of new memories on each topic,
       then delete the mega-memory. The new memories should cumulatively contain all information that the mega-memory contained.
    7. If two memories overlap, update_memory on one, remove_memories on the other

    You can use `add_memories` to add more than one memory at once, or `update_memories` to update multiple at once.

    The same rules apply for identity - use replace_identity if you need to rewrite, not add_identity to append duplicates.

    You started dreaming at #{Lobber.Conversation.now()}

    Your starting memories:
    #{memories}

    Today's conversation history:

    #{Lobber.Cave.todays_conversation_history()}
    """
  end

  @impl true
  def run() do
    Logger.info("Running deep sleep memory consolidation...")

    {:ok, conversation} = Lobber.Conversations.get_or_spawn("system", "memory_consolidation")
    :ok = Lobber.Conversation.clear(conversation)
    :ok = Lobber.Conversation.reload(conversation)

    Lobber.Conversation.add_message(
      conversation,
      :do_not_reply,
      prompt(),
      %{
        agent_options: [
          starting_tools: [
            Lobber.Tools.Remember,
            Lobber.Tools.UpdateMemory,
            Lobber.Tools.RemoveMemories,
            Lobber.Tools.ListMemories,
            Lobber.Tools.AddIdentity,
            Lobber.Tools.ReplaceIdentity
          ]
        ]
      }
    )
  end
end
