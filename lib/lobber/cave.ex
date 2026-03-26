defmodule Lobber.Cave do
  @moduledoc """
  Sets up the cave and such so we can keep our lobber's personality through reboots
  lobber lives in cave, lobber has a nice cave

  @memories - where lobber stores what it wants to remember
  """
  require Logger

  @memories "THINKS.md"
  @store "shiny_things"
  @conversations "conversations"
  @identity "IDENTITY.md"
  @tools "tools"
  @config "config"

  @ensure_dirs [
    @store,
    @tools,
    @config,
    @conversations
  ]

  defp cave() do
    Lobber.Config.get(:cave)
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

  defp ensure_dirs() do
    for dir <- @ensure_dirs do
      unless File.exists?(file_path(dir)) do
      File.mkdir_p(file_path(dir))
      end
    end
  end

  def custom_tools() do
    {:ok, tools, _} =
      @tools
      |> file_path()
      |> File.ls!()
      |> Enum.map(fn path ->
        @tools
        |> file_path()
        |> Path.join(path)
      end)
      |> Kernel.ParallelCompiler.compile(return_diagnostics: true)
      |> IO.inspect()

    tools
  end

  def promote_tool(name) do
    fname = "tool-proposal-#{name}.ex"

    tool_fname =
      @tools
      |> file_path()
      |> Path.join(fname)

    @store
    |> file_path()
    |> Path.join(fname)
    |> File.cp(tool_fname)
  end

  defp ensure_memories() do
    unless File.exists?(file_path(@memories)) do
      :ok =
        Lobber.Config.priv_path("cave/THINKS.md")
        |> File.cp(file_path(@memories))
    end
  end

  defp ensure_identity() do
    unless File.exists?(file_path(@identity)) do
      :ok =
        Lobber.Config.priv_path("cave/IDENTITY.md")
        |> File.cp(file_path(@identity))
    end
  end

  def ensure() do
    Logger.info("Checking lobber cave...")
    ensure_cave()
    ensure_memories()
    ensure_identity()
    ensure_dirs()
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

  @doc """
  Read a file from lobber's cave

  Lobber.Cave.read_from_cave("config/auth.json")
  => {:ok, data}
  """
  def read_from_cave(file_name) do
    {:ok, path} = Path.safe_relative(file_name)

    path =
      cave()
      |> Path.join(path)

    File.read(path)
  end

  @doc """
  Write a file to lobber's cave

  Lobber.Cave.write_to_cave("config/auth.json")
  => :ok
  """
  def write_to_cave(file_name, content) do
    {:ok, path} = Path.safe_relative(file_name)

    path =
      cave()
      |> Path.join(path)

    Logger.info("Writing to #{path}")

    File.write(path, content)
  end

  def remember(content) do
    memories = file_path(@memories)
    {:ok, old} = File.read(memories)
    File.write(memories, "#{old}\n#{content}")
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

  defp conversation_backup_path(id) do
    path =
      cave()
      |> Path.join(@conversations)
      |> Path.join("#{id}.json")

    {:ok, path} = Path.safe_relative(path, cave())
    path
  end

  def backup_conversation(id, content) do
    {:ok, data} = Jason.encode(content)

    path = conversation_backup_path(id)
    File.write(path, data)
  end

  def read_backup(id) do
    path = conversation_backup_path(id)

    if File.exists?(path) do
      {:ok, data} = File.read(path)
      {:ok, conv} = Jason.decode(data)
      conv
    else
      []
    end
    |> Enum.map(&Lobber.Conversation.Message.decode/1)
  end

  def add_to_identity(data) do
    identity = file_path(@identity)
    {:ok, old} = File.read(identity)
    File.write(identity, "#{old}\n#{data}")
  end

  def overwrite_identity(data) do
    @identity
    |> file_path()
    |> File.write(data)
  end
end
