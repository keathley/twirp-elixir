defmodule Twirp.PlugTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias Twirp.Error

  defmodule Size do
    @moduledoc false
    use Protobuf, syntax: :proto3

    defstruct [:inches]

    field :inches, 1, type: :int32
  end

  defmodule Hat do
    @moduledoc false
    use Protobuf, syntax: :proto3

    @derive Jason.Encoder
    defstruct [:color]

    field :color, 2, type: :string
  end

  defmodule Service do
    use Twirp.Service

    package "plug.test"
    service "Haberdasher"

    rpc :MakeHat, Size, Hat, :make_hat
  end

  defmodule GoodHandler do
    def make_hat(_env, %Size{inches: inches}) do
      if inches <= 0 do
        Error.invalid_argument("I can't make a hat that small!")
      else
        %Hat{color: "red"}
      end
    end
  end

  defmodule EmptyHandler do
  end

  defmodule BadHandler do
    def make_hat(_env, size) do
      size
    end
  end

  defmodule Client do
    use Twirp.Client, service: Service
  end

  @opts Twirp.Plug.init([service: Service, handler: GoodHandler])

  def json_req(method, payload) do
    endpoint = "/twirp/plug.test.Haberdasher/#{method}"

    body = if is_map(payload), do: Jason.encode!(payload), else: payload

    :post
    |> conn(endpoint, body)
    |> put_req_header("content-type", "application/json")
  end

  def proto_req(method, payload) do
    endpoint = "/twirp/plug.test.Haberdasher/#{method}"

    mod = payload.__struct__

    :post
    |> conn(endpoint, mod.encode(payload))
    |> put_req_header("content-type", "application/protobuf")
  end

  def content_type(conn) do
    conn.resp_headers
    |> Enum.find_value(fn {h, v} -> if h == "content-type", do: v, else: false end)
    |> String.split(";") # drop the charset if there is one
    |> Enum.at(0)
  end

  def call(req, opts \\ @opts) do
    Twirp.Plug.call(req, opts)
  end

  test "json request" do
    req = json_req("MakeHat", %{inches: 10})
    conn = call(req)

    assert conn.status == 200
  end

  test "proto request" do
    req = proto_req("MakeHat", Size.new(inches: 10))
    conn = call(req)

    assert conn.status == 200
    assert Hat.new(color: "red") == Hat.decode(conn.resp_body)
  end

  test "non twirp requests" do
    req = conn(:post, "/anotherurl")
    conn = call(req)

    assert conn == req
  end

  test "twirp requests to a different service" do
    req = conn(:post, "/twirp/another.service.Service")
    conn = call(req)

    assert conn == req
  end

  test "not a POST" do
    req = conn(:get, "/twirp/plug.test.Haberdasher/MakeHat")
    conn = call(req)

    assert conn.status == 404
    assert content_type(conn) == "application/json"
    body = Jason.decode!(conn.resp_body)
    assert body["code"] == "bad_route"
    assert body["msg"] == "HTTP request must be POST"
    assert body["meta"] == %{
      "twirp_invalid_route" => "GET /twirp/plug.test.Haberdasher/MakeHat"
    }
  end

  test "request has incorrect content type" do
    req = conn(:post, "/twirp/plug.test.Haberdasher/MakeHat")
          |> put_req_header("content-type", "application/msgpack")
    conn = call(req)

    assert conn.status == 404
    assert content_type(conn) == "application/json"
    body = Jason.decode!(conn.resp_body)
    assert body["code"] == "bad_route"
    assert body["msg"] == "Unexpected Content-Type: application/msgpack"
    assert body["meta"] == %{
      "twirp_invalid_route" => "POST /twirp/plug.test.Haberdasher/MakeHat"
    }
  end

  test "request has no content-type" do
    req = conn(:post, "/twirp/plug.test.Haberdasher/MakeHat")
    conn = call(req)

    assert conn.status == 404
    assert content_type(conn) == "application/json"
    body = Jason.decode!(conn.resp_body)
    assert body["code"] == "bad_route"
    assert body["msg"] == "Unexpected Content-Type: nil"
    assert body["meta"] == %{
      "twirp_invalid_route" => "POST /twirp/plug.test.Haberdasher/MakeHat"
    }
  end

  test "handler doesn't define function" do
    {service_def, _} = Twirp.Plug.init([service: Service, handler: Handler])
    req = proto_req("MakeHat", Size.new(inches: 10))

    # We need to manually set options like this to skip the
    # compile time checking done in init.
    conn = call(req, {service_def, EmptyHandler})
    assert conn.status == 501
    assert content_type(conn) == "application/json"
    resp = Jason.decode!(conn.resp_body)
    assert resp["code"] == "unimplemented"
    assert resp["msg"] == "Handler function make_hat is not implemented"
  end

  test "unknown method" do
    req = proto_req("MakeShoes", Size.new(inches: 10))
    conn = call(req)

    assert conn.status == 404
    assert content_type(conn) == "application/json"
    resp = Jason.decode!(conn.resp_body)
    assert resp["code"] == "bad_route"
    assert resp["msg"] == "Invalid rpc method: MakeShoes"
    assert resp["meta"] == %{
      "twirp_invalid_route" => "POST /twirp/plug.test.Haberdasher/MakeShoes"
    }
  end

  test "bad json message" do
    req = json_req("MakeHat", "not json")
    conn = call(req)

    assert conn.status == 404
    assert content_type(conn) == "application/json"
    resp = Jason.decode!(conn.resp_body)
    assert resp["code"] == "bad_route"
    assert resp["msg"] == "Invalid request body for rpc method: MakeHat"
    assert resp["meta"] == %{
      "twirp_invalid_route" => "POST /twirp/plug.test.Haberdasher/MakeHat"
    }
  end

  test "bad proto message" do
    req =
      :post
      |> conn("/twirp/plug.test.Haberdasher/MakeHat", "bad protobuf")
      |> put_req_header("content-type", "application/protobuf")
    conn = call(req)

    assert conn.status == 404
    assert content_type(conn) == "application/json"
    resp = Jason.decode!(conn.resp_body)
    assert resp["code"] == "bad_route"
    assert resp["msg"] == "Invalid request body for rpc method: MakeHat"
    assert resp["meta"] == %{
      "twirp_invalid_route" => "POST /twirp/plug.test.Haberdasher/MakeHat"
    }
  end

  test "handler returns incorrect response" do
    opts = Twirp.Plug.init([service: Service, handler: BadHandler])
    req = proto_req("MakeHat", Size.new(inches: 10))
    conn = call(req, opts)

    assert conn.status == 500
    assert content_type(conn) == "application/json"
    resp = Jason.decode!(conn.resp_body)
    assert resp["code"] == "internal"
    assert resp["msg"] == "Handler method make_hat expected to return one of Elixir.Twirp.PlugTest.Hat or Twirp.Error but returned %Twirp.PlugTest.Size{inches: 10}"
  end

  test "handler doesn't return an error, struct or map" do
    defmodule InvalidHandler do
      def make_hat(_, _) do
        "invalid"
      end
    end

    opts = Twirp.Plug.init([service: Service, handler: InvalidHandler])
    req = proto_req("MakeHat", Size.new(inches: 10))
    conn = call(req, opts)

    assert conn.status == 500
    assert content_type(conn) == "application/json"
    resp = Jason.decode!(conn.resp_body)
    assert resp["code"] == "internal"
    assert resp["msg"] == "Handler method make_hat expected to return one of Elixir.Twirp.PlugTest.Hat or Twirp.Error but returned \"invalid\""
  end

  test "handler receives env" do
    req = proto_req("MakeHat", Size.new(inches: 10))
    conn = call(req)

    assert conn.status == 200
    assert Hat.new(color: "red") == Hat.decode(conn.resp_body)
    flunk "Not Implemented"
  end

  @tag :skip
  test "handler raises exception" do
    flunk "Not Implemented"
  end

  describe "before hook" do
    test "is called with a context" do
      flunk "Not Implemented"
    end
  end
end
