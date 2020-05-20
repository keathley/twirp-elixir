defmodule Twirp.ClientTest do
  use ExUnit.Case, async: false

  alias Twirp.Error

  alias Twirp.Test.Req
  alias Twirp.Test.Resp
  alias Twirp.Test.EchoClient, as: Client

  setup tags do
    service = Bypass.open()
    base_url = "http://localhost:#{service.port}"
    content_type = tags[:client_type] || :proto
    start_supervised({Client, url: base_url, content_type: content_type})

    {:ok, service: service}
  end

  test "generated clients have rpc functions defined on them" do
    assert {:echo, 2} in Client.__info__(:functions)
  end

  test "generated clients include a generic rpc function" do
    assert {:rpc, 3} in Client.__info__(:functions)
  end

  test "makes an http call if the rpc is defined", %{service: service} do
    Bypass.expect(service, fn conn ->
      assert Plug.Conn.get_req_header(conn, "content-type") == ["application/protobuf"]
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert %Req{msg: "test"} == Req.decode(body)

      body = Resp.encode(Resp.new(msg: "test"))

      conn
      |> Plug.Conn.put_resp_content_type("application/protobuf")
      |> Plug.Conn.resp(200, body)
    end)

    resp = Client.rpc(:Echo, Req.new(msg: "test"))
    assert {:ok, Resp.new(msg: "test")} == resp
  end

  @tag client_type: :json
  test "json encoding and decoding", %{service: service} do
    Bypass.expect(service, fn conn ->
      assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert %{"msg" => "Test"} == Jason.decode!(body)

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s|{"msg": "Test"}|)
    end)

    assert {:ok, resp} = Client.echo(Req.new(msg: "Test"))
    assert match?(%Resp{}, resp)
    assert resp.msg == "Test"
  end

  test "if rpc is not defined return an error" do
    {:error, resp} = Client.rpc(:Undefined, Req.new(msg: "test"))
    assert match?(%Twirp.Error{code: :bad_route}, resp)
  end

  test "incorrect headers are returned", %{service: service} do
    Bypass.expect(service, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/msgpack")
      |> Plug.Conn.resp(200, ~s|foo|)
    end)

    assert {:error, resp} = Client.echo(Req.new(msg: "test"))
    assert match?(%Error{code: :internal}, resp)
  end

  test "no headers are returned", %{service: service} do
    Bypass.expect(service, fn conn ->
      conn
      |> Plug.Conn.resp(200, ~s|foo|)
    end)

    assert {:error, resp} = Client.echo(Req.new(msg: "test"))
    assert match?(%Error{code: :internal}, resp)
    assert resp.msg == ~s|Expected response Content-Type "application/protobuf" but found nil|
  end

  test "error is not json", %{service: service} do
    Bypass.expect(service, fn conn ->
      conn
      |> Plug.Conn.send_resp(503, ~s|plain text error|)
    end)

    assert {:error, resp} = Client.echo(Req.new(msg: "test"))
    assert resp.code == :unavailable
    assert resp.msg == "unavailable"
    assert resp.meta.http_error_from_intermediary == "true"
    assert resp.meta.not_a_twirp_error_because == "Response is not JSON"
    assert resp.meta.body == "plain text error"
  end

  test "error has no code", %{service: service} do
    Bypass.expect(service, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(500, ~s|{"msg": "I have no code"}|)
    end)

    assert {:error, resp} = Client.echo(Req.new(msg: "test"))
    assert resp.code == :unknown
    assert resp.msg == "unknown"
    assert resp.meta.http_error_from_intermediary == "true"
    assert resp.meta.not_a_twirp_error_because == "Response is JSON but it has no \"code\" attribute"
  end

  test "error has incorrect code", %{service: service} do
    Bypass.expect(service, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(500, ~s|{"code": "keathley", "msg": "incorrect code"}|)
    end)

    assert {:error, resp} = Client.echo(Req.new(msg: "test"))
    assert resp.code == :internal
    assert resp.msg == "Invalid Twirp error code: keathley"
    assert resp.meta.invalid_code == "keathley"
  end

  test "redirect errors", %{service: service} do
    Bypass.expect(service, fn conn ->
      url = "https://keathley.io"

      conn
      |> Plug.Conn.put_resp_header("location", url)
      |> Plug.Conn.send_resp(302, url)
    end)

    assert {:error, resp} = Client.echo(Req.new(msg: "test"))
    assert match?(%Error{code: :internal}, resp)
    assert resp.meta.http_error_from_intermediary == "true"
    assert resp.meta.not_a_twirp_error_because == "Redirects not allowed on Twirp requests"
  end

  test "service is down", %{service: service} do
    Bypass.down(service)

    assert {:error, resp} = Client.echo(Req.new(msg: "test"))
    assert resp.code == :unavailable
  end

  @tag :skip
  test "clients are easy to stub" do
    Twirp.Client.Stub.new(echo: fn %{msg: "foo"} ->
      Error.unavailable("test")
    end)
    assert {:error, %Error{code: :unavailable}} = Client.echo(Req.new(msg: "foo"))

    Twirp.Client.Stub.new(echo: fn %{msg: "foo"} ->
      Resp.new(msg: "foo")
    end)
    assert {:ok, %Resp{msg: "foo"}} = Client.echo(Req.new(msg: "foo"))

    assert_raise Twirp.Client.StubError, ~r/does not define/, fn ->
      Twirp.Client.Stub.new()
      Client.echo(Req.new(msg: "foo"))
    end

    assert_raise Twirp.Client.StubError, ~r/expected to return/, fn ->
      Twirp.Client.Stub.new(echo: fn _ ->
        {:ok, Req.new(msg: "test")}
      end)
      Client.echo(Req.new(msg: "foo"))
    end
  end
end
