defmodule Lobber.Provider.Behaviour do
  @moduledoc """
  Behaviour that providers must implement
  """

  @callback prompt(list(), binary(), list()) :: {:text, binary()} | {atom(), binary()}
end
