defmodule Lobber.Cave do
  @moduledoc """
  Sets up the cave and such so we can keep our lobber's personality through reboots
  lobber lives in cave, lobber has a nice cave

  It's a whole bunch of persistence mechanisms.
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

  defp recompile_custom_tools() do
    @tools
    |> file_path()
    |> File.ls!()
    |> Enum.map(fn path ->
      @tools
      |> file_path()
      |> Path.join(path)
    end)
    |> Kernel.ParallelCompiler.compile(return_diagnostics: true)
  end

  def reload() do
    recompile_custom_tools()
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

  def promote_mod(name) do
    fname = "proposal-#{name}.ex"
    Logger.info("Promoting #{fname}...")

    mod_fname =
      @tools
      |> file_path()
      |> Path.join(fname)

    @store
    |> file_path()
    |> Path.join(fname)
    |> File.cp!(mod_fname)
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
    recompile_custom_tools()
  end

  def format_for_prompt() do
    [
      @identity,
      @memories
    ]
    |> Enum.map(&file_path/1)
    |> Enum.map_join("\n", fn f ->
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

    # Ensure content doesn't have newlines that would break structure
    clean_content = String.replace(content, "\n", " ")

    # Add timestamp for better tracking
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    new_entry = "[#{timestamp}] #{clean_content}"

    # Write with proper newline handling
    new_content =
      if String.trim(old) == "" do
        new_entry
      else
        "#{old}\n#{new_entry}"
      end

    File.write(memories, new_content)
  end

  @doc """
  List all memories with their IDs (line numbers)
  Returns {:ok, [{id, content}, ...]} or {:error, reason}
  """
  def list_memories() do
    memories_path = file_path(@memories)

    case File.read(memories_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")
        # Filter out empty lines and add IDs
        memories =
          lines
          |> Enum.with_index(1)
          |> Enum.reject(fn {line, _id} -> String.trim(line) == "" end)
          |> Enum.map(fn {line, id} -> {id, line} end)

        {:ok, memories}

      {:error, reason} ->
        {:error, "Could not read memories: #{reason}"}
    end
  end

  @doc """
  Remove a memory by its ID (line number)
  Returns :ok or {:error, reason}
  """
  def remove_memory(memory_id) when is_binary(memory_id) do
    {id, _} = Integer.parse(memory_id)
    remove_memory(id)
  end

  def remove_memory(memory_id) when is_integer(memory_id) and memory_id > 0 do
    memories_path = file_path(@memories)

    case File.read(memories_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")

        if memory_id > length(lines) do
          {:error, :not_found}
        else
          # Remove the line at the given position
          new_lines = List.delete_at(lines, memory_id - 1)
          new_content = Enum.join(new_lines, "\n")
          File.write(memories_path, new_content)
          :ok
        end

      {:error, reason} ->
        {:error, "Could not read memories: #{reason}"}
    end
  end

  @doc """
  Update a memory by its ID (line number)
  Returns :ok or {:error, reason}
  """
  def update_memory(memory_id, new_content) when is_integer(memory_id) and memory_id > 0 do
    memories_path = file_path(@memories)

    case File.read(memories_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")

        if memory_id > length(lines) do
          {:error, :not_found}
        else
          # Clean the new content
          clean_content = String.replace(new_content, "\n", " ")
          timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
          updated_entry = "[#{timestamp}] #{clean_content}"

          # Replace the line at the given position
          new_lines = List.replace_at(lines, memory_id - 1, updated_entry)
          new_content_str = Enum.join(new_lines, "\n")
          File.write(memories_path, new_content_str)
          :ok
        end

      {:error, reason} ->
        {:error, "Could not read memories: #{reason}"}
    end
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
