defmodule Lobber.Conversations do
  use DynamicSupervisor

  require Logger

  @registry Registry.LobberConversations
  def registry(), do: @registry

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  defp conversation_id(provider, id), do: "#{provider}:#{id}"
  defp process_name(id), do: {:via, Registry, {registry(), id}}

  def get_or_spawn(provider, id) do
    conversation = conversation_id(provider, id)
    Logger.info("Looking up #{conversation}")

    case Registry.lookup(registry(), conversation) do
      [{pid, _value}] -> pid
      [] -> spawn_new(conversation)
    end
  end

  defp spawn_new(id) do
    Logger.info("Spawning conversation #{id}")

    spec = {Lobber.Conversation, [name: process_name(id), id: id]}

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} ->
        pid

      {:ok, pid, _info} ->
        pid

      {:error, err} ->
        Logger.error("Could not start child! #{inspect(err)}")
        :error
    end
  end
end
