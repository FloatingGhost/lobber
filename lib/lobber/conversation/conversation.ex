defmodule Lobber.Conversation do
  alias Lobber.Conversation.Message

  def add_message(history, %Message{} = next) do
    history ++ [next]
  end
end
