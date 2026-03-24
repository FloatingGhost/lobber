defmodule Lobber.Channels.Discord.DiscordMessage do
  alias Lobber.Channels.Discord.Opcodes

  defstruct opcode: nil, data: %{}, sequence_number: nil, type: ""

  def decode(s) when is_binary(s) do
    case Jason.decode(s) do
      {:ok, msg} -> decode(msg)
      _ -> :error
    end
  end

  def decode(
        %{
          "op" => op,
          "d" => d,
          "s" => s
        } = msg
      ) do
    %__MODULE__{
      opcode: Opcodes.human(op),
      data: d,
      sequence_number: s,
      type: Map.get(msg, "t", "")
    }
  end

  def encode(%__MODULE__{
        opcode: opcode,
        data: d,
        sequence_number: s
      }) do
    %{
      "op" => Opcodes.opcode(opcode),
      "d" => d,
      "s" => s
    }
    |> Jason.encode()
  end
end
