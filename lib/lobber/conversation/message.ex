defmodule Lobber.Conversation.Message do
  defstruct role: "", content: "", tool_calls: [], tool_call_id: nil

  def decode(%{
        "role" => role,
        "content" => content,
        "tool_calls" => tool_calls
      }) do
    %__MODULE__{
      role: role,
      content: content,
      tool_calls: Enum.map(tool_calls, &Lobber.Conversation.ToolCall.decode/1)
    }
  end

  def decode(%{
        "role" => role,
        "content" => content
      }) do
    %__MODULE__{
      role: role,
      content: content,
      tool_calls: []
    }
  end

  def encode(%__MODULE__{
        role: role,
        content: content,
        tool_calls: tool_calls,
        tool_call_id: tool_call_id
      }) do
    %{
      "role" => role,
      "content" => content,
      "tool_calls" => Enum.map(tool_calls, &Lobber.Conversation.ToolCall.encode/1),
      "tool_call_id" => tool_call_id
    }
  end
end

defimpl Jason.Encoder, for: Lobber.Conversation.Message do
  def encode(value, opts) do
    value
    |> Lobber.Conversation.Message.encode()
    |> Jason.Encode.map(opts)
  end
end
