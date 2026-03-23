defmodule Lobber.Conversation.ToolCall do
  defstruct id: "", name: "", arguments: %{}

  def decode(%{"id" => id, "function" => %{"name" => name, "arguments" => arguments}}) do
    {:ok, args} = Jason.decode(arguments)

    %__MODULE__{
      id: id,
      name: name,
      arguments: args
    }
  end

  def encode(%__MODULE__{
        id: id,
        name: name,
        arguments: arguments
      }) do
      {:ok, args} = Jason.encode(arguments)
    %{
      "id" => id,
      "function" => %{
        "name" => name,
        "arguments" => args
      }
    }
  end
end

defimpl Jason.Encoder, for: Lobber.Conversation.ToolCall do
  def encode(value, opts) do
    value
    |> Lobber.Conversation.ToolCall.encode()
    |> Jason.Encode.map(opts)
  end
end
