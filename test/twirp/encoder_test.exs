defmodule Twirp.EncoderTest do
  use ExUnit.Case, async: true

  alias Twirp.Encoder
  alias Twirp.TestService.Req
  alias Twirp.TestService.ReqNoJsonProtocol
  alias Twirp.TestService.ReqSub

  describe "decode/3 with json" do
    test "converts json to protobuf" do
      assert {:ok, %Req{msg: "test"}} = Encoder.decode(%{msg: "test"}, Req, "application/json")
    end
  end

  describe "encode/3 as json " do
    test "encodes to JSON without implementing a JSON protocol" do
      assert ~S({"msg":"test","sub":{"msg":"test"}}) ==
        Encoder.encode(%ReqNoJsonProtocol{msg: "test", sub: %ReqSub{msg: "test"}}, ReqNoJsonProtocol, "application/json")
    end
  end
end
