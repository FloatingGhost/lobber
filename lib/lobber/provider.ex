defmodule Lobber.Provider do
  @behaviour Lobber.Provider.Behaviour

  defp provider() do
    Lobber.Config.get(:provider)
  end

  def prompt(conversation, next_message, tools) do
    provider().prompt(conversation, next_message, tools)
  end
end
