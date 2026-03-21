defmodule Lobber.System do
  @moduledoc """
  Defines the system settings for lobber
  Things like its system prompt
  """

  def system_prompt() do
    built_in = File.read!("priv/SYSTEM.md")
    memories = Lobber.Cave.format_for_prompt()
    tools = Lobber.Tools.as_text()
    "#{built_in}

    #{memories}

    You have the following tools available to you:
    #{tools}

    Remember, you may have to add a tool to your context via add_tool"
  end
end
