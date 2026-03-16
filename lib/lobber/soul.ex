defmodule Lobber.Soul do
  @moduledoc """
  Sets up the soul and such so we can keep our lobber's personality through reboots
  """
  require Logger

  @memories "MEMORIES.md"

  # hehe souldir boy
  defp soul_dir() do
    Application.get_env(:lobber, :soul_directory)
  end

  defp file_path(path) do
    joined = Path.join(soul_dir(), path)
    {:ok, path} = Path.safe_relative(joined, soul_dir())
    path
  end

  defp ensure_soul() do
    unless File.exists?(soul_dir()) do
      File.mkdir(soul_dir())
    end
  end

  defp ensure_memories() do
    unless File.exists?(file_path(@memories)) do
      :ok = File.cp("priv/soul/MEMORIES.md", file_path(@memories))
    end
  end

  def ensure() do
    Logger.info("Ensuring we have a soul...")
    ensure_soul()
    ensure_memories()
  end

  def format_for_prompt() do
    [
      @memories
    ]
    |> Enum.map(&file_path/1)
    |> Enum.map(fn f ->
      {:ok, contents} = File.read(f)
      contents
    end)
  end

  def remember(content) do
    File.write(file_path(@memories), content)
  end
end
