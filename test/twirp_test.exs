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
    use Twirp.Service

    package "twirp.integration.test"
    service "TestService"

    rpc :Echo, TestReq, TestResp, :echo
  end

  defmodule TestClient do
    use Twirp.Client, service: TestService
  end

  defmodule TestHandler do
    def echo(_conn, %TestReq{msg: msg}) do
      IO.inspect(msg, label: "Got message")

      %TestResp{msg: msg}
    end
  end

  defmodule TestRouter do
    use Plug.Builder

    plug TestService, handler: TestHandler
  end

  setup_all do
    {:ok, _} = Plug.Cowboy.http TestRouter, [port: 4002]

    :ok
  end

  test "clients can call services" do
    IO.inspect(TestClient.__info__(:functions), label: "Functions")
    client = TestClient.new("http://localhost:4002")
    req = TestReq.new(msg: "Hello there")

    assert {:ok, %TestResp{}=resp} = TestClient.echo(client, req)
    assert resp.msg == "Hello there"
  end
end

