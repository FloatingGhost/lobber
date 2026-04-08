defmodule Lobber.Provider.OpenAICompatible do
  @moduledoc """
  Base handlers for openai-compatible providers
  """
  alias Lobber.Conversation
  require Logger

  def headers(api_key) do
    [
      {"authorization", "Bearer #{api_key}"}
    ]
  end

  def client(base_url, api_key) do
    Tesla.client([
      Tesla.Middleware.Logger,
      {Tesla.Middleware.Retry, delay: 500, max_retries: 5, max_delay: 4_000},
      {Tesla.Middleware.Timeout, timeout: :infinity},
      {Tesla.Middleware.BaseUrl, base_url},
      {Tesla.Middleware.Headers, headers(api_key)},
      Tesla.Middleware.JSON
    ])
  end

  def prompt(
        base_url,
        api_key,
        model_id,
        history,
        %Conversation.Message{} = s,
        tools,
        extra_request_options,
        opts \\ [adapter: Lobber.Provider.Adapter.NoOp]
      ) do
    history = Conversation.concat_messages(history, s)
    adapter = Keyword.get(opts, :adapter)

    adapted_history =
      Enum.map(history, fn msg ->
        Conversation.Message.encode(msg) |> adapter.outbound_message()
      end)

    {:ok, messages} =
      Jason.encode(
        extra_request_options
        |> Map.merge(%{
          messages: adapted_history,
          model: model_id,
          tools: Lobber.Tools.format(tools)
        })
      )

    Tesla.post(client(base_url, api_key), "/v1/chat/completions", messages)
    |> maybe_log_usage()
    |> handle_resp(history, tools, opts)
  end

  defp maybe_log_usage({:ok, %Tesla.Env{status: 200, body: %{"usage" => %{"total_tokens" => tokens, "completion_tokens" => compl_tokens}}}} = msg) do
    Logger.info("Used #{tokens} tokens, of which #{compl_tokens} were output")
    msg
  end

  defp maybe_log_usage(msg), do: msg

  defp handle_resp(
         {:ok, %Tesla.Env{status: 200, body: %{"choices" => [choice]}}},
         history,
         tools,
         opts
       ) do
    handle_message(history, choice, tools, opts)
  end

  defp handle_resp({:ok, %Tesla.Env{status: 400, body: body}}, _, _, _) do
    Logger.error("Bad request to OpenAI! #{inspect(body)}")
    :error
  end

  defp handle_resp({:ok, other}, _, _, _) do
    Logger.error("Could not handle OpenAI response! #{inspect(other)}")
    :error
  end

  defp handle_resp({:error, :timeout}, _history, _tools, _opts) do
    Logger.error("OpenAI timed out!")
    :error
  end

  defp handle_message(_history, %{"finish_reason" => "stop", "message" => message}, _, opts) do
    adapter = Keyword.get(opts, :adapter)

    message
    |> adapter.inbound_message()
    |> Conversation.Message.decode()
  end

  defp handle_message(
         history,
         %{
           "finish_reason" => "tool_calls",
           "message" => message
         },
         _tools,
         opts
       ) do
    adapter = Keyword.get(opts, :adapter)

    message =
      message
      |> adapter.inbound_message()
      |> Conversation.Message.decode()

    {:tools, message.tool_calls, history ++ [message]}
  end

  defp handle_message(_history, other, _tools, _opts) do
    Logger.error("OpenAI failed!")
    Logger.error(inspect(other))
    :error
  end
end
