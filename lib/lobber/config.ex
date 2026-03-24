defmodule Lobber.Config do
  @moduledoc """
  Helper functions for getting lobber-specific config
  Helps with keeping the config file nice and tidy
  """

  def get(key) do
    case Application.fetch_env(:lobber, key) do
      {:ok, value} -> value
      :error -> nil
    end
  end

  def get(key, subkey) do
    with {:ok, value} <- Application.fetch_env(:lobber, key),
         {:has, true} <- {:has, Keyword.has_key?(value, subkey)} do
      Keyword.get(value, subkey)
    else
      _ -> {:error, :no_key}
    end
  end
end
