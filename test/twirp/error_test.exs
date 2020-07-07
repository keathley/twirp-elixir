defmodule Twirp.ErrorTest do
  use ExUnit.Case, async: true

  alias Twirp.Error

  describe "message/1 callback" do
    test "returns the msg value" do
      error = Error.new(:invalid_argument, "I can't make a hat that small!")
      assert "I can't make a hat that small!" == Exception.message(error)
    end
  end

  test "can raise exception" do
    assert_raise Twirp.Error, ~r|hat that small|, fn ->
      raise Error.invalid_argument("I can't make a hat that small!")
    end
  end
end
