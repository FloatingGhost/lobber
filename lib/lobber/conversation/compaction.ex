defmodule Lobber.Conversation.Compaction do
  @moduledoc """
  A module to hold functions relating to context compaction
  Context grows over time, ad we'll want to sometimes shove it back into one message
  """

  alias Lobber.Conversation.Message

  @compaction_system """
  You are a conversation summariser. You will be provided with an entire conversation following this
  system message. Your goal is to summarise the contents of the conversation into a few sentences,
  retaining important details and dropping unimportant details or stylistic information. The point of this
  process is to allow a new agent to understand what has been spoken about without having to read the entire
  conversation history.
  Do not retain extraneous information, only retain the important points of the conversation.
  Keep your compacted conversation brief and to the point, and start each message with "The following is a recap of this conversation:"
  """

  def compact([%Message{role: "system"} | rest]), do: compact(rest)

  def compact(history) do
    system = %Message{
      role: "system",
      content: @compaction_system
    }

    request = %Message{
      role: "user",
      content: "Please summarise this conversation!"
    }

    %Message{content: text} = Lobber.Provider.prompt([system | history], request, [])

    %Message{
      role: "user",
      content: text
    }
  end
end
