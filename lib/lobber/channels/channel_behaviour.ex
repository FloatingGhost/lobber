defmodule Lobber.Channel.Behaviour do
  @moduledoc """
  A behaviour that channels must implement
  """

  @callback name() :: binary()
end
