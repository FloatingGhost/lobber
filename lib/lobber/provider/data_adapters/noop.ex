defmodule Lobber.Provider.Adapter.NoOp do
  @behaviour Lobber.Provider.Adapter.Behaviour

  @impl true
  def inbound_message(msg), do: msg
  @impl true
  def outbound_message(msg), do: msg
end
