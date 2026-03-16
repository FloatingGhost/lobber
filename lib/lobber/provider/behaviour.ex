defmodule Lobber.Provider.Behaviour do
  @callback prompt(list(), binary()) :: {:text, binary()} | {atom(), binary()}
end
