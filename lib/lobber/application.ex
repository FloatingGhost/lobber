defmodule Lobber.Application do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting supervision")

    children = [
      {Lobber.Discord.Socket, []}
    ]

    opts = [strategy: :one_for_one, name: Lobber.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
