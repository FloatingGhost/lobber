defmodule Lobber.Provider.NoOp do
  @moduledoc """
  A no-op provider for use when testing providers,
  """

  @behaviour Lobber.Provider.Behaviour

  require Logger

  @impl true
  def name(), do: "noop"

  @impl true
  def prompt(_history, next, _tools, _model, opts) do
    Logger.info("Called NoOp provider with:")
    Logger.info(inspect(next))
    Logger.info("Options:")
    Logger.info(inspect(opts))

    %Lobber.Conversation.Message{
      role: "assistant",
      content: "noop"
    }
  end
end
