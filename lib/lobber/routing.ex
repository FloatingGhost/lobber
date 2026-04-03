defmodule Lobber.Routing do
  @moduledoc """
  Defines routing behaviour from tasks to providers
  Configured in config.exs
  """

  require Logger

  @routing_map %{
    Lobber.Conversation.Compaction => :conversation_compaction
  }

  defp map_mod_to_task(mod) do
    Map.get(@routing_map, mod, :default)
  end

  @doc """
  Returns the routing for a given module

  iex> Lobber.Routing.routing_for(Lobber.Conversation.Compaction)
  [provider: Lobber.Provider.Xiaomi, model_id: "xiaomi/something"]
  """
  @spec routing_for(atom()) :: keyword()
  def routing_for(mod) do
    task = map_mod_to_task(mod)
    overrides = Lobber.Config.get(__MODULE__, task)

    if is_nil(overrides) do
      default_routing()
    else
      Logger.debug("Using routing override: #{mod} - #{task} #{inspect(overrides)}")
      overrides
    end
  end

  defp default_routing() do
    Lobber.Config.get(__MODULE__, :default)
  end

  @doc """
  Inject the default routing options to ensure everything is populated
  """
  def with_defaults(opts) do
    default_routing()
    |> Keyword.merge(Keyword.reject(opts, fn {_k, val} -> is_nil(val) end))
  end
end
