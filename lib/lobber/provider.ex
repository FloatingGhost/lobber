defmodule Lobber.Provider do
  @provider Application.compile_end(:lobber, :provider, nil)
  @behaviour Lobber.Provider.Behaviour

  defdelegate prompt(conversation, next_message), to: @provider
end
