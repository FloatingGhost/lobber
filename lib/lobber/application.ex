defmodule Lobber.Application do
  @moduledoc """
  Primary supervision tree. No real logic should live in here,
  this is purely starting our application
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting supervision")

    Lobber.Cave.ensure()
    channels = Lobber.Config.get(:channels)

    children = [
      {Registry, [keys: :unique, name: Lobber.Conversations.registry()]},
      {Lobber.Config.Holder, []},
      {Task.Supervisor, name: Lobber.Agent.supervisor()},
      {Lobber.Channels, channels},
      {Lobber.Conversations, []}
    ]

    opts = [strategy: :one_for_one, name: Lobber.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
