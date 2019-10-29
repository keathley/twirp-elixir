defmodule TwirpTest do
  use ExUnit.Case
  doctest Twirp

  test "greets the world" do
    assert Twirp.hello() == :world
  end
end
