defmodule Lobber.Config.Holder do
  @moduledoc """
  Organisation supervisor to keep global state config
  Not strictly needed but keeps config agents out of application.ex
  """

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
