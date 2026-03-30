defmodule Lobber.Provider.OpenRouter do
  @moduledoc """
  Implementation of the OpenRouter provider - this is openapi compatible,
  """

  @behaviour Lobber.Provider.Behaviour

  require Logger

  @openrouter "https://openrouter.ai/api"
  @extra_options %{
    provider: %{
      sort: %{
        by: "throughput"
      }
    }
  }

  @impl true
  def name(), do: "openrouter"

  defp model do
    Lobber.Config.get(__MODULE__, :model_id)
  end

  defp api_key do
    Lobber.Config.get(__MODULE__, :api_key)
  end

  def prompt(history, next, tools) do
    Lobber.Provider.OpenAICompatible.prompt(
      @openrouter,
      api_key(),
      model(),
      history,
      next,
      tools,
      @extra_options
    )
  end
end
