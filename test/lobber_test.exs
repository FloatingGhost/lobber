defmodule LobberTest do
  use ExUnit.Case
  doctest Lobber

  test "greets the world" do
    assert Lobber.hello() == :world
  end
end
