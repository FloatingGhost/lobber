defmodule Lobber.Provider do
  @moduledoc """
  Delegation processing for LLM providers.
  Will send off requests to the currently configured provider
  """

  @behaviour Lobber.Provider.Behaviour

  alias Lobber.Provider
  require Logger

  # 100% here to make sure everything gets brought in by the compiler
  @providers [
    Provider.OpenRouter,
    Provider.Xiaomi
  ]

  defp provider() do
    Lobber.Config.get(:provider)
  end

  def by_name(name) do
    @providers
    |> Enum.find(fn mod -> mod.name() == name end)
  end

  @doc """
  Request the currently configured provider to process your request.
  """
  @impl true
  def prompt(conversation, next_message, tools) do
    Logger.info("Calling #{provider().name()}")
    provider().prompt(conversation, next_message, tools)
  end

  # we need to implement this to meet the behaviour
  def name(), do: "meta"
end
