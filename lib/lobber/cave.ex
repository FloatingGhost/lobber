defmodule Lobber.Cave do
  @moduledoc """
  Sets up the cave and such so we can keep our lobber's personality through reboots
  lobber lives in cave, lobber has a nice cave

  @memories - where lobber stores what it wants to remember
  """
  require Logger

  @memories "THINKS.md"
  @store "shiny_things"

  defp cave() do
    Application.get_env(:lobber, :cave)
  end

  defp file_path(path) do
    joined = Path.join(cave(), path)
    {:ok, path} = Path.safe_relative(joined, cave())
    path
  end

  defp ensure_cave() do
    unless File.exists?(cave()) do
      File.mkdir(cave())
    end
  end

  defp ensure_store() do
    unless File.exists?(file_path(@store)) do
      File.mkdir(file_path(@store))
    end
  end

  defp ensure_memories() do
    unless File.exists?(file_path(@memories)) do
      :ok = File.cp("priv/cave/THINKS.md", file_path(@memories))
    end
  end

  def ensure() do
    Logger.info("Checking lobber cave...")
    ensure_cave()
    ensure_memories()
    ensure_store()
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

  def store(file_name, content) do
    path =
      cave()
      |> Path.join(@store)
      |> Path.join(file_name)

    Logger.info("Storing in #{path}")

    {:ok, path} = Path.safe_relative(path, cave())
    File.write(path, content)
  end
end
