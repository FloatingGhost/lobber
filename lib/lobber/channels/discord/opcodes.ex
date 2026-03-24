defmodule Lobber.Channels.Discord.Opcodes do
  @opcodes %{
    dispatch: 0,
    heartbeat: 1,
    identify: 2,
    presence: 3,
    voice_state: 4,
    resume: 6,
    reconnect: 7,
    request_guild_members: 8,
    invalid_session: 9,
    hello: 10,
    heartbeat_ACK: 11,
    request_soundboard_sounds: 31
  }

  def opcode(human) do
    if Map.has_key?(@opcodes, human) do
      Map.get(@opcodes, human)
    else
      -1
    end
  end

  def human(opcode) do
    h = Enum.find(@opcodes, fn {k, v} -> v == opcode end)

    if is_nil(h) do
      "Unknown Opcode"
    else
      {k, _} = h
      k
    end
  end
end
