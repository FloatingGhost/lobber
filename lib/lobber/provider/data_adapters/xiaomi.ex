defmodule Lobber.Provider.Adapter.Xiaomi do
  @behaviour Lobber.Provider.Adapter.Behaviour

  @impl true
  def inbound_message(%{"reasoning_content" => reasoning} = msg) do
    msg
    |> Map.delete("reasoning_content")
    |> Map.put("reasoning", reasoning)
    |> inbound_message()
  end

  def inbound_message(other), do: other

  @impl true
  def outbound_message(%{"reasoning" => reasoning} = msg) do
    msg
    |> Map.delete("reasoning")
    |> Map.put("reasoning_content", reasoning)
    |> outbound_message()
  end

  def outbound_message(other), do: other
end
