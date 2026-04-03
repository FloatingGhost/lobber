defmodule Lobber.Channels.Discord.Commands do
  alias Lobber.Channels.Discord.Client

  require Logger

  defp commands() do
    [
      %{
        name: "reload",
        type: 1,
        description: "Reload the conversation"
      },
      %{
        name: "clear",
        type: 1,
        description: "Clear the conversation"
      },
      %{
        name: "compact",
        type: 1,
        description: "Compact the conversation's context"
      },
      %{
        name: "provider",
        type: 1,
        description: "Set the provider for this conversation",
        options: [
          %{
            name: "provider",
            description: "the provider name",
            type: 3,
            required: true,
            choices:
              Lobber.Provider.list()
              |> Enum.map(fn provider ->
                %{
                  name: provider.name(),
                  value: to_string(provider)
                }
              end)
          }
        ]
      },
      %{
        name: "model_id",
        type: 1,
        description: "Set the provider for this conversation",
        options: [
          %{
            name: "provider",
            description: "the provider name",
            type: 3,
            required: true
          }
        ]
      }
    ]
  end

  def format(%{"options" => options, "name" => command_name}) do
    "!!#{command_name} #{Enum.map_join(options, " ", fn %{"value" => value} -> value end)}"
  end

  def format(%{"name" => command_name}), do: "!!#{command_name}"

  def my_id() do
    client = Client.client()
    {:ok, %Tesla.Env{body: body}} = Tesla.get(client, "/api/v10/applications/@me")
    %{"id" => id} = body
    id
  end

  def create_commands() do
    id = my_id()
    client = Client.client()

    {:ok, %Tesla.Env{status: 200}} =
      Tesla.put(client, "/api/v10/applications/#{id}/commands", commands())
  end

  def delete_all_commands() do
    id = my_id()
    client = Client.client()
    {:ok, %Tesla.Env{body: body}} = Tesla.get(client, "/api/v10/applications/#{id}/commands")

    Enum.each(body, fn %{"id" => cmd_id} ->
      Logger.info("Removed command #{cmd_id}")
      {:ok, _} = Tesla.delete(client, "/api/v10/applications/#{id}/commands/#{cmd_id}")
    end)
  end
end
