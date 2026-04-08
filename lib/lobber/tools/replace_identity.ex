defmodule Lobber.Tools.ReplaceIdentity do
  @moduledoc false
  @behaviour Lobber.Tool.Behaviour

  def name(), do: "replace_identity"

  def description(),
    do: """
        Totally overwrite your identity. Will remove all previous data in your identity file and replace it
        with the data given to this tool.
    """

  def parameters(),
    do: %{
      content: %{
        type: "string"
      }
    }

  def run(%{"content" => content}) do
    :ok = Lobber.Cave.overwrite_identity(content)
    {:ok, new} = Lobber.Cave.identity()
    {:string, "Your identity has been saved\nYour identity is now:\n#{new}"}
  end
end
