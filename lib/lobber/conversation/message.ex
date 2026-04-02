defmodule Lobber.Conversation.Message do
  @moduledoc """
  Represents a single message in a conversation.
  Can be from the user or the model
  """

  defstruct role: "",
            content: "",
            tool_calls: [],
            tool_call_id: nil,
            reasoning: nil,
            reasoning_details: nil

  defp empty_list_if_nil(nil), do: []
  defp empty_list_if_nil(other), do: other

  def decode(
        %{
          "role" => role,
          "content" => content
        } = data
      ) do
    %__MODULE__{
      role: role,
      content: content
    }
    |> Map.put(
      :tool_calls,
      Enum.map(
        Map.get(data, "tool_calls", []) |> empty_list_if_nil(),
        &Lobber.Conversation.ToolCall.decode/1
      )
    )
    |> Map.put(:tool_call_id, Map.get(data, "tool_call_id", nil))
    |> Map.put(:reasoning, Map.get(data, "reasoning", nil))
    |> Map.put(:reasoning_details, Map.get(data, "reasoning_details", nil))
  end

  def encode(%__MODULE__{
        role: role,
        content: content,
        tool_calls: tool_calls,
        tool_call_id: tool_call_id,
        reasoning: reasoning,
        reasoning_details: reasoning_details
      }) do
    %{
      "role" => role,
      "content" => content
    }
    |> maybe_put_tool_calls(tool_calls)
    |> maybe_put_tool_call_id(tool_call_id)
    |> maybe_put_reasoning(reasoning)
    |> maybe_put_reasoning_details(reasoning_details)
  end

  defp maybe_put_tool_calls(map, []), do: map

  defp maybe_put_tool_calls(map, tool_calls) do
    Map.put(map, "tool_calls", Enum.map(tool_calls, &Lobber.Conversation.ToolCall.encode/1))
  end

  defp maybe_put_tool_call_id(map, nil), do: map

  defp maybe_put_tool_call_id(map, tool_call_id) do
    Map.put(map, "tool_call_id", tool_call_id)
  end

  defp maybe_put_reasoning(map, nil), do: map

  defp maybe_put_reasoning(map, content) do
    Map.put(map, "reasoning", content)
  end

  defp maybe_put_reasoning_details(map, nil), do: map

  defp maybe_put_reasoning_details(map, content) do
    Map.put(map, "reasoning_details", content)
  end
end

defimpl Jason.Encoder, for: Lobber.Conversation.Message do
  def encode(value, opts) do
    value
    |> Lobber.Conversation.Message.encode()
    |> Jason.Encode.map(opts)
  end
end
