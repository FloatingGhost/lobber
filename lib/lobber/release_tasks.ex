defmodule Lobber.ReleaseTasks do
  def prompt(s) do
    {:ok, conversation} = Lobber.Conversations.get_or_spawn("system", "console")

    Lobber.Conversation.add_message(
      conversation,
      self(),
      s,
      %{}
    )

    receive do
      {:"$gen_cast", {:conversation_response, %{content: content}, _opts}} ->
        IO.puts(content)
    after
      120_000 ->
        "No response in 2 mins :("
    end
  end
end
