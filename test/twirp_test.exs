defmodule TwirpTest do
  use ExUnit.Case, async: false

  alias Twirp.Test.EchoService, as: Service
  alias Twirp.Test.EchoClient, as: Client
  alias Twirp.Test.Req
  alias Twirp.Test.Resp

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

    plug Plug.Parsers, parsers: [:urlencoded, :json],
      pass: ["*/*"],
      json_decoder: Jason

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
    {:ok, _} = start_supervised({Client, url: "http://localhost:4002"})
    req = Req.new(msg: "Hello there")

    assert {:ok, %Resp{}=resp} = Client.echo(req)
    assert resp.msg == "Hello there"
  end

  test "can call services with json" do
    {:ok, _} = start_supervised({Client, url: "http://localhost:4002", content_type: :json})
    req = Req.new(msg: "Hello there")

    assert {:ok, %Resp{}=resp} = Client.echo(req)
    assert resp.msg == "Hello there"
  end

  test "users can specify deadlines" do
    {:ok, _} = start_supervised({Client, url: "http://localhost:4002"})
    req = Req.new(msg: "Hello there")

    assert {:error, resp} = Client.slow_echo(%{deadline: 5}, req)
    assert resp.code == :deadline_exceeded
    assert resp.meta["error_type"] == "timeout"
  end

  test "clients allow interceptors" do
    ref = make_ref()
    us = self()

    interceptors = [
      fn ctx, req, next ->
        deadline = ctx.deadline
        ctx = %{ctx | headers: [{"x-twirp-deadline", to_string(deadline)} | ctx.headers]}
        next.(ctx, req)
      end,
      fn ctx, req, next ->
        send(us, {ref, ctx, req})
        next.(ctx, req)
      end
    ]

    start_supervised({Client, url: "http://localhost:4002", interceptors: interceptors})

    assert {:ok, req} = Client.echo(%{deadline: 1000}, Req.new(msg: "Test"))
    assert req.msg == "Test"

    assert_receive {^ref, ctx, _req}
    assert {"x-twirp-deadline", "1000"} in ctx.headers
  end

  test "errors halt the call chain" do
    ref = make_ref()
    us = self()

    interceptors = [
      fn _ctx, _req, _next ->
        {:error, Twirp.Error.resource_exhausted("Client is over concurrency limit")}
      end,
      fn ctx, req, next ->
        send(us, {ref, ctx, req})
        next.(ctx, req)
      end
    ]

    start_supervised({Client, url: "http://localhost:4002", interceptors: interceptors})

    assert {:error, %Twirp.Error{}} = Client.echo(%{deadline: 1000}, Req.new(msg: "Test"))

    refute_receive {^ref, _ctx, _req}
  end
end
