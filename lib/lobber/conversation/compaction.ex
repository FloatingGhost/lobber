defmodule Lobber.Conversation.Compaction do
  @moduledoc """
  A module to hold functions relating to context compaction
  Context grows over time, ad we'll want to sometimes shove it back into one message
  """

  alias Lobber.Conversation.Message
  alias Lobber.Routing

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

    %Message{content: text} =
      Lobber.Provider.prompt([system | history], request, [], Routing.routing_for(__MODULE__))

    %Message{
      role: "user",
      content: text
    }
  end

  @spec partially_compact(list(Message.t()), integer) :: list(Message.t())
  def partially_compact(history, leg_retention) do
    {remaining_history, to_compact} = split_legs(history, leg_retention)

    msg =
      to_compact
      |> Enum.reverse()
      |> compact()

    [msg | Enum.reverse(remaining_history)]
  end

  @spec split_legs(list(Message.t()), integer) :: {list(Message.t()), list(Message.t())}
  defp split_legs([%Message{role: "system"} | rest], to_retain) do
    messages = Enum.reverse(rest)
    split_at = find_split_point(messages, to_retain, 0, 0)
    Enum.split(messages, split_at)
  end

  @spec find_split_point(list(Message.t()), integer, integer, integer) :: integer
  defp find_split_point(_, to_retain, to_retain, index), do: index

  defp find_split_point([%Message{role: "user"} | rest], to_retain, seen, index) do
    find_split_point(rest, to_retain, seen + 1, index + 1)
  end

  defp find_split_point([_ | rest], to_retain, seen, index) do
    find_split_point(rest, to_retain, seen, index + 1)
  end

  defp find_split_point([], _, _, index), do: index
end
