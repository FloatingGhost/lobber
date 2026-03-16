defmodule Lobber.Tool.Behaviour do
  @callback name() :: binary

  @callback description() :: binary

  @callback parameters() :: term | nil

  @callback run() :: {:add_tool, atom} | {:string, string}
end
