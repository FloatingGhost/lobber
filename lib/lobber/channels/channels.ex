defmodule Lobber.Channels do
  @moduledoc """
  Collection supervisor that will keep all channels alive. Will be passed a list
  of children by its parent.
  """
  use Supervisor

  def registry() do
    Registry.LobberChannels
  end

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(init_arg) do
    Supervisor.init(init_arg, strategy: :one_for_one)
  end
end
