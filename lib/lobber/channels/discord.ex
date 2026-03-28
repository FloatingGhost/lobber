defmodule Lobber.Channels.Discord do
  @moduledoc """
  Higher-level supervisor for discord, ensures that the websocket dying is fully isolated from the main
  application
  """
  use Supervisor

  @behaviour Lobber.Channel.Behaviour

  @name "discord"

  def start_link(_) do
    Supervisor.start_link(
      __MODULE__,
      [
        {Lobber.Channels.Discord.Socket, [channel_name: @name]}
      ],
      name: __MODULE__
    )
  end

  @impl true
  def init(init_arg) do
    Supervisor.init(init_arg, strategy: :one_for_one)
  end

  @impl true
  def name(), do: @name
end
