defmodule Lobber.Provider.Behaviour do
  @moduledoc """
  Behaviour that providers must implement
  """

  @callback name() :: binary()

  @doc """
  Calls the actual provider

  prompt(history, next_message, tools, model_id)
  iex> prompt([%{role: "system", content: "prompt"}], %{role: "user", content: "abc", tools, model_id})
  """
  @callback prompt(
              list(Lobber.Conversation.Message.t()),
              Lobber.Conversation.Message.t(),
              list,
              binary
            ) :: {:text, binary} | {atom, binary}
end
