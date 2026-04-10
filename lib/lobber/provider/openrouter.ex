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

  defp api_key do
    Lobber.Config.get(__MODULE__, :api_key)
  end

  @impl true
  def prompt(history, next, tools, model, _opts) do
    Lobber.Provider.OpenAICompatible.prompt(
      @openrouter,
      api_key(),
      model,
      history,
      next,
      tools,
      @extra_options
    )
  end
end
