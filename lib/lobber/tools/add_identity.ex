defmodule Lobber.Tools.AddIdentity do
  @moduledoc false

  @behaviour Lobber.Tool.Behaviour

  def name(), do: "add_identity"

  def description(),
    do: """
        Add some data to your identity. Will append the data you give it to your identity file for later use
    """

  def parameters(),
    do: %{
      content: %{
        type: "string"
      }
    }

  def run(%{"content" => content}) do
    :ok = Lobber.Cave.add_to_identity(content)
    {:string, "Your identity has been saved"}
  end
end
