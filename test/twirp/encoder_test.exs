defmodule Twirp.EncoderTest do
  use ExUnit.Case, async: true

  alias Twirp.Encoder
  alias Twirp.TestService.Req

  describe "decode/3 with json" do
    test "converts json to protobuf" do
      assert {:ok, %Req{msg: "test"}} = Encoder.decode(%{msg: "test"}, Req, "application/json")
    end
  end
end
