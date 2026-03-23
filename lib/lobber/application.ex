defmodule Lobber.Application do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting supervision")

    Lobber.Cave.ensure()

    Lobber.System.system_prompt() |> IO.inspect()

    children = [
      {Registry, [keys: :unique, name: Lobber.Conversations.registry()]},
      {Task.Supervisor, name: Lobber.Agent.supervisor()},
      {Lobber.Channels,
       [
         {Lobber.Discord.Socket, []}
       ]},
      {Lobber.Conversations, []}
    ]

    opts = [strategy: :one_for_one, name: Lobber.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
