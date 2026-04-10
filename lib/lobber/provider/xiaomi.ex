defmodule Lobber.Provider.Xiaomi do
  @moduledoc """
  Implementation of the Xiaomi provider
  """

  @behaviour Lobber.Provider.Behaviour

  require Logger

  @xiaomi "https://api.xiaomimimo.com"
  @xiaomi_plan "https://token-plan-ams.xiaomimimo.com"

  @impl true
  def name(), do: "xiaomi"

  defp type() do
    Lobber.Config.get(__MODULE__, :type)
  end

  defp url() do
    case type() do
      :token_plan -> @xiaomi_plan
      :standard -> @xiaomi
    end
  end

  defp api_key do
    Lobber.Config.get(__MODULE__, :api_key)
  end

  defp image_model() do
    Lobber.Config.get(__MODULE__, :image_model)
  end

  defp select_model(default, opts) do
    if Keyword.get(opts, :image_understanding) do
      Logger.debug("Using image model!")
      image_model()
    else
      default
    end
  end

  @impl true
  def prompt(history, next, tools, model, opts) do
    Lobber.Provider.OpenAICompatible.prompt(
      url(),
      api_key(),
      select_model(model, opts),
      history,
      next,
      tools,
      %{},
      adapter: Lobber.Provider.Adapter.Xiaomi
    )
  end
end
