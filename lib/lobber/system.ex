defmodule Lobber.System do
  @moduledoc """
  Defines the system settings for lobber
  Things like its system prompt
  """

  def system_prompt() do
    built_in = File.read!("priv/SYSTEM.md")
    memories = Lobber.Soul.format_for_prompt()

    "#{built_in}
    #{memories}"
  end
end
