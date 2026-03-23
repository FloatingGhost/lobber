defmodule Lobber.Provider.Behaviour do
  @callback prompt(list(), binary(), list()) :: {:text, binary()} | {atom(), binary()}
end
