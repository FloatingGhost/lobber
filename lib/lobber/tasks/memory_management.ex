defmodule Lobber.Tasks.MemoryManagement do
  @behaviour Lobber.Tasks.Behaviour

  require Logger

  def prompt() do
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

    You started dreaming at #{Lobber.Conversation.now()}

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
