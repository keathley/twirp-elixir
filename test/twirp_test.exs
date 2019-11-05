defmodule TwirpTest do
  use ExUnit.Case, async: false

  alias Twirp.TestService.{
    Req,
    Resp,
    Client,
    Service,
  }

  defmodule Handler do
    def echo(_conn, %Req{msg: msg}) do
      %Resp{msg: msg}
    end

    def slow_echo(_conn, %Req{msg: msg}) do
      :timer.sleep(50)
      %Resp{msg: msg}
    end
  end

  defmodule TestRouter do
    use Plug.Router

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

  setup do
    client = Client.client("http://localhost:4002", [])

    {:ok, client: client}
  end

  test "clients can call services", %{client: client} do
    req = Req.new(msg: "Hello there")

    assert {:ok, %Resp{}=resp} = Client.echo(client, req)
    assert resp.msg == "Hello there"
  end

  test "users can specify deadlines", %{client: client} do
    req = Req.new(msg: "Hello there")

    assert {:error, resp} = Client.slow_echo(client, req, timeout: 5)
    assert resp.code == :deadline_exceeded
    assert resp.meta.timeout == "5"
  end

  # test "test what happens if the client hits a service endpoint that doesn't exist" do
  #   flunk "Not Implemented"
  # end
end
