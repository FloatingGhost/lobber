defmodule Lobber.Config.Auth do
  @moduledoc """
  Agent that holds dynamic authentication data, backed up on modification
  """

  use Agent
  require Logger

  @config_file "config/auth.json"

  alias Lobber.Cave

  def start_link(_init) do
    initial_value =
      case Cave.read_from_cave(@config_file) do
        {:ok, data} -> Jason.decode!(data)
        _ -> []
      end

    Agent.start_link(fn -> save_config(initial_value) end, name: __MODULE__)
  end

  defp value do
    Agent.get(__MODULE__, & &1)
  end

  def authorize(id) do
    Logger.info("Authorizing #{id}")
    current = value()

    Agent.update(__MODULE__, fn state ->
      [id | state]
      |> save_config()
    end)
  end

  def authorized?(id) do
    value()
    |> Enum.member?(id)
  end

  defp save_config(value) do
    {:ok, data} = Jason.encode(value)
    Cave.write_to_cave(@config_file, data)
    value
  end
end
