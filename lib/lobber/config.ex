defmodule Lobber.Config do
  @moduledoc """
  Helper functions for getting lobber-specific config
  Helps with keeping the config file nice and tidy
  """

  def get(key) do
    Application.fetch_env!(:lobber, key)
  end

  def get(key, subkey) do
    with {:ok, value} <- Application.fetch_env(:lobber, key),
         {:has, true} <- {:has, Keyword.has_key?(value, subkey)} do
      Keyword.get(value, subkey)
    else
      _ -> raise "No such config #{key}->#{subkey}"
    end
  end
end
