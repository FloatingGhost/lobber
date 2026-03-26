defmodule Lobber.Config.Holder do
  use Supervisor

  def start_link(_) do
    Supervisor.start_link(
      __MODULE__,
      [
        {Lobber.Config.Auth, []}
      ],
      name: __MODULE__
    )
  end

  @impl true
  def init(init_arg) do
    Supervisor.init(init_arg, strategy: :one_for_one)
  end
end
