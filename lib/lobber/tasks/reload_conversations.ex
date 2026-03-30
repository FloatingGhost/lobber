defmodule Lobber.Tasks.Reload do
  @behaviour Lobber.Tasks.Behaviour

  require Logger

  def run() do
    Logger.info("Reloading all conversations...")
    Lobber.Conversations.reload_all()
  end
end
