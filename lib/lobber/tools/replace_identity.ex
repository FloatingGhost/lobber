defmodule Lobber.Tools.ReplaceIdentity do
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
    {:string, "Your identity has been saved"}
  end
end
