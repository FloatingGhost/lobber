defmodule Lobber.Provider.Xiaomi do
  @moduledoc """
  Implementation of the Xiaomi provider
  """

  @behaviour Lobber.Provider.Behaviour

  alias Lobber.Conversation

  require Logger

  @xiaomi "https://api.xiaomimimo.com"

  defp model do
    Lobber.Config.get(__MODULE__, :model_id)
  end

  defp api_key do
    Lobber.Config.get(__MODULE__, :api_key)
  end

  def prompt(history, next, tools) do
    Lobber.Provider.OpenAICompatible.prompt(
      @xiaomi,
      api_key(),
      model(),
      history,
      next,
      tools,
      %{},
      adapter: Lobber.Provider.Adapter.Xiaomi
    )
  end
end
