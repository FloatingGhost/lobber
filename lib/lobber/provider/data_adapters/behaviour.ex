defmodule Lobber.Provider.Adapter.Behaviour do
  @moduledoc """
  Behaviour that data adapters must implement
  """

  @callback inbound_message(map()) :: map()
  @callback outbound_message(map()) :: map()
end
