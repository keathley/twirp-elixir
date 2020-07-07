defmodule Twirp.ErrorTest do
  use ExUnit.Case, async: true

  alias Twirp.Error

  describe "message/1 callback" do
    test "returns the msg value" do
      error = Error.new(:invalid_argument, "I can't make a hat that small!")
      assert "I can't make a hat that small!" == Exception.message(error)
    end
  end
end
