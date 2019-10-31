defmodule TwirpTest do
  use ExUnit.Case
  doctest Twirp

  defmodule TestReq do
    use Protobuf, syntax: :proto3

    @derive Jason.Encoder
    defstruct [:msg]

    field :msg, 1, type: :string
  end

  defmodule TestResp do
    use Protobuf, syntax: :proto3

    @derive Jason.Encoder
    defstruct [:msg]

    field :msg, 1, type: :string
  end

  defmodule TestService do
    def definition do
      %{
        package: "twirp.integration.test",
        service: "TestService",
        rpcs: [
          %{method: :Echo, input: TestReq, output: TestResp, handler_fn: :echo}
        ]
      }
    end
  end

  defmodule TestClient do
    use Twirp.Client, service: TestService
  end

  defmodule TestHandler do
    def echo(_conn, %TestReq{msg: msg}) do
      %TestResp{msg: msg}
    end
  end

  defmodule TestRouter do
    use Plug.Router

    plug Plug.Logger, log: :debug
    plug Twirp.Plug, service: TestService, handler: TestHandler

    plug :match

    match _ do
      send_resp(conn, 404, "oops")
    end
  end

  setup_all do
    {:ok, _} = Plug.Cowboy.http TestRouter, [], [port: 4002]

    :ok
  end

  test "clients can call services" do
    client = TestClient.client("http://localhost:4002", [])

    req = TestReq.new(msg: "Hello there")

    assert {:ok, %TestResp{}=resp} = TestClient.echo(client, req)
    assert resp.msg == "Hello there"
  end
end

