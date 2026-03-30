defmodule Lobber.Conversations do
  @moduledoc """
  The supervisor watching over all conversations with lobber.
  Can have new conversations spawned under it at any time.
  All conversations are registered against Registry.LobberConversations for later reference
  """

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

  def conversation_id(provider, id), do: "#{provider}:#{id}"
  defp process_name(id), do: {:via, Registry, {registry(), id}}

  @spec get_or_spawn(binary(), binary()) :: {:ok, pid()} | {:error, :needs_auth, binary()}
  def get_or_spawn(provider, id) do
    conversation = conversation_id(provider, id)

    if Lobber.Config.Auth.authorized?(conversation) do
      Logger.info("Looking up #{conversation}")

      case Registry.lookup(registry(), conversation) do
        [{pid, _value}] -> {:ok, pid}
        [] -> spawn_new(conversation)
      end
    else
      {:error, :needs_auth, conversation}
    end
  end

  defp spawn_new(id) do
    Logger.info("Spawning conversation #{id}")

    spec = {Lobber.Conversation, [name: process_name(id), id: id]}

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} ->
        {:ok, pid}

      {:ok, pid, _info} ->
        {:ok, pid}

      {:error, err} ->
        Logger.error("Could not start child! #{inspect(err)}")
        :error
    end
  end

  def stop(id) do
    case Registry.lookup(registry(), id) do
      [{pid, _value}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> :no_process
    end
  end
end
