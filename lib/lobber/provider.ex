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

  def by_name(name) do
    @providers
    |> Enum.find(fn mod -> mod.name() == name end)
  end

  def list() do
    @providers
  end

  @doc """
  Request a provider to process your request.
  Will either use the provider in `routing_opts`, or the `:default` if nothing is specified
  """
  @impl true
  def prompt(conversation, next_message, tools, routing_opts \\ []) do
    routing_opts = Lobber.Routing.with_defaults(routing_opts)
    provider = Keyword.get(routing_opts, :provider)
    model = Keyword.get(routing_opts, :model_id)
    Logger.info("Calling #{model}@#{provider.name()}")
    provider.prompt(conversation, next_message, tools, model)
  end

  # we need to implement this to meet the behaviour
  @impl true
  def name(), do: "meta"
end
