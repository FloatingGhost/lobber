defmodule Lobber.System do
  @moduledoc """
  Defines the system settings for lobber
  Things like its system prompt
  """

  def system_prompt() do
    built_in = Lobber.Config.read_priv("SYSTEM.md")
    memories = Lobber.Cave.format_for_prompt()
    tools = Lobber.Tools.as_text()
    skills = Lobber.Skills.format()
    "#{built_in}

    #{memories}

    You have the following tools available to you:
    #{tools}

    You have the following skills:
    #{skills}

    Remember, you may have to add a tool to your context via add_tool"
  end
end
