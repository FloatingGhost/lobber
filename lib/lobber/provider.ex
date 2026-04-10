defmodule Lobber.Provider do
  @moduledoc """
  Delegation processing for LLM providers.
  Will send off requests to the currently configured provider
  """

  alias Lobber.Provider
  require Logger

  # 100% here to make sure everything gets brought in by the compiler
  @providers [
    Provider.OpenRouter,
    Provider.Xiaomi,
    Provider.NoOp
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
  def prompt(conversation, next_message, tools, routing_opts \\ []) do
    routing_opts = Lobber.Routing.with_defaults(routing_opts)

    provider_opts = with_image_understanding([], next_message)

    provider = Keyword.get(routing_opts, :provider)
    model = Keyword.get(routing_opts, :model_id)
    Logger.info("Calling #{model}@#{provider.name()}")
    provider.prompt(conversation, next_message, tools, model, provider_opts)
  end

  defp with_image_understanding(opts, next_message) do
    Keyword.put(opts, :image_understanding, image_understanding_needed?(next_message))
  end

  defp image_understanding_needed?(%{content: content}) when is_list(content) do
    Enum.any?(content, fn block -> Map.get(block, :type) == "image_url" end)
  end

  defp image_understanding_needed?(_), do: false
end
