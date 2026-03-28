defmodule Lobber.Tool.Behaviour do
  @moduledoc """
  A behaviour that tools should implement to be added to the tool list.
  """
  @callback name() :: binary

  @callback description() :: binary

  @callback parameters() :: term | nil

  @callback run(map()) :: {:add_tool, atom} | {:string, string}
end
