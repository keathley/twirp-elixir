defmodule TwirpTest do
  use ExUnit.Case, async: false
  doctest Twirp

  alias Twirp.TestService.{
    Req,
    Resp,
    Client,
    Service,
    Handler,
  }

  defmodule TestRouter do
    use Plug.Router

    # plug Plug.Logger, log: :error
    plug Twirp.Plug, service: Service, handler: Handler

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
    client = Client.client("http://localhost:4002", [])

    req = Req.new(msg: "Hello there")

    assert {:ok, %Resp{}=resp} = Client.echo(client, req)
    assert resp.msg == "Hello there"
  end
end

