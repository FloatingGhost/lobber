defmodule Lobber.Provider do
  @moduledoc """
  Delegation processing for LLM providers.
  Will send off requests to the currently configured provider
  """

  @behaviour Lobber.Provider.Behaviour

  defp provider() do
    Lobber.Config.get(:provider)
  end

  @doc """
  Request the currently configured provider to process your request.
  """
  @impl true
  def prompt(conversation, next_message, tools) do
    provider().prompt(conversation, next_message, tools)
  end
end
