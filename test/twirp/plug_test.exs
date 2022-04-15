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

  test "does not include the __exception__ field" do
    req = conn(:get, "/twirp/plug.test.Haberdasher/MakeHat")
    conn = call(req)

    assert conn.status == 404
    assert content_type(conn) == "application/json"
    body = Jason.decode!(conn.resp_body)
    refute Map.has_key?(body, "__exception__")
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
    opts = Twirp.Plug.init([service: Service, handler: EmptyHandler])
    req = proto_req("MakeHat", Size.new(inches: 10))

    # We need to manually set options like this to skip the
    # compile time checking done in init.
    conn = call(req, opts)
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

  describe "when the body has been pre-parsed" do
    test "json requests use the body params" do
      req = json_req("MakeHat", %{})
      req = Map.put(req, :body_params, %{"inches" => 10})
      conn = call(req)

      assert conn.status == 200
      assert resp = Jason.decode!(conn.resp_body)
      assert resp["color"] != nil
    end

    test "returns errors if the payload is incorrect" do
      req = json_req("MakeHat", %{})
      req = Map.put(req, :body_params, %{"keathley" => "bar"})
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
  end

  test "handler receives env" do
    defmodule HandlerWithEnv do
      def make_hat(env, _) do
        assert Norm.valid?(env, Norm.selection(Twirp.Plug.env_s()))
      end
    end

    opts = Twirp.Plug.init([service: Service, handler: RaiseHandler])
    req = proto_req("MakeHat", Size.new(inches: 10))
    call(req, opts)
  end

  test "handler raises exception" do
    defmodule RaiseHandler do
      def make_hat(_env, _size) do
        raise ArgumentError, "Blow this ish up"
      end
    end

    opts = Twirp.Plug.init([service: Service, handler: RaiseHandler])
    req = proto_req("MakeHat", Size.new(inches: 10))
    conn = call(req, opts)

    assert conn.status == 500
    assert content_type(conn) == "application/json"
    resp = Jason.decode!(conn.resp_body)
    assert resp["code"] == "internal"
    assert resp["msg"] == "Blow this ish up"
    refute Map.has_key?(resp, "meta")
  end

  describe "before" do
    test "hooks are run before the handler is called" do
      us = self()

      f = fn conn, env ->
        assert %Plug.Conn{} = conn
        assert Norm.valid?(env, Norm.selection(Twirp.Plug.env_s()))
        assert env.input == Size.new(inches: 10)
        send(us, :plug_called)
        env
      end

      opts = Twirp.Plug.init [
        service: Service,
        handler: GoodHandler,
        before: [f]
      ]
      req = proto_req("MakeHat", Size.new(inches: 10))
      _conn = call(req, opts)
      assert_receive :plug_called
    end

    test "hooks can update the env" do
      us = self()

      first = fn _conn, env ->
        Map.put(env, :test, :foobar)
      end

      second = fn _conn, env ->
        assert env.test == :foobar
        send(us, :done)
        env
      end

      opts = Twirp.Plug.init [
        service: Service,
        handler: GoodHandler,
        before: [first, second]
      ]
      req = proto_req("MakeHat", Size.new(inches: 10))
      _conn = call(req, opts)
      assert_receive :done
    end

    test "before hooks are halted if they return an error" do
      first = fn _conn, _env ->
        Twirp.Error.permission_denied("You're not authorized for this")
      end
      second = fn _conn, _env ->
        flunk "I should never make it here"
      end

      opts = Twirp.Plug.init [
        service: Service,
        handler: GoodHandler,
        before: [first, second]
      ]
      req = proto_req("MakeHat", Size.new(inches: 10))
      _conn = call(req, opts)
    end

    test "returns the most recent env" do
      us = self()

      first = fn _conn, env ->
        Map.put(env, :test, "This is a test")
      end
      second = fn _conn, _env ->
        Twirp.Error.permission_denied("Bail out")
      end

      error = fn env, error ->
        assert error == Twirp.Error.permission_denied("Bail out")
        assert env.test == "This is a test"

        send us, :done
      end

      opts = Twirp.Plug.init [
        service: Service,
        handler: GoodHandler,
        before: [first, second],
        on_error: [error]
      ]
      req = proto_req("MakeHat", Size.new(inches: 10))
      _conn = call(req, opts)

      assert_receive :done
    end
  end

  describe "on_success hooks" do
    test "are called if the rpc handler was successful" do
      us = self()

      first = fn env ->
        assert env.output == Hat.encode(Hat.new(color: "red"))
        send us, :done
      end

      opts = Twirp.Plug.init [
        service: Service,
        handler: GoodHandler,
        on_success: [first]
      ]
      req = proto_req("MakeHat", Size.new(inches: 10))
      _conn = call(req, opts)
      assert_receive :done
    end
  end

  describe "on_error hooks" do
    test "run if the handler returns an error" do
      defmodule ErrorHandler do
        def make_hat(_, _) do
          Twirp.Error.permission_denied("not allowed")
        end
      end

      us = self()

      first = fn _env, error ->
        assert error == Twirp.Error.permission_denied("not allowed")
        send us, :done
      end

      opts = Twirp.Plug.init [
        service: Service,
        handler: ErrorHandler,
        on_error: [first]
      ]
      req = proto_req("MakeHat", Size.new(inches: 10))
      conn = call(req, opts)
      assert_receive :done

      assert conn.status == 403
      error = Jason.decode!(conn.resp_body)
      assert error["code"] == "permission_denied"
    end

    test "are called if there was an exception" do
      defmodule ExceptionToErrorHandler do
        def make_hat(_, _) do
          raise ArgumentError, "Boom!"
        end
      end

      us = self()

      on_error = fn _env, error ->
        assert error == Twirp.Error.internal("Boom!")
        send us, :done
      end

      opts = Twirp.Plug.init [
        service: Service,
        handler: ExceptionToErrorHandler,
        on_error: [on_error]
      ]
      req = proto_req("MakeHat", Size.new(inches: 10))
      conn = call(req, opts)
      assert_receive :done

      assert conn.status == 500
      error = Jason.decode!(conn.resp_body)
      assert error["code"] == "internal"
    end
  end

  describe "on_exception hooks" do
    test "are called if there is an exception raised while processing the call" do
      defmodule ExceptionHandler do
        def make_hat(_, _) do
          raise ArgumentError, "Boom!"
        end
      end

      us = self()

      first = fn env, exception ->
        assert Norm.valid?(env, Twirp.Plug.env_s())
        assert match?(%ArgumentError{}, exception)
        send us, :done
      end

      opts = Twirp.Plug.init [
        service: Service,
        handler: ExceptionHandler,
        on_exception: [first]
      ]
      req = proto_req("MakeHat", Size.new(inches: 10))
      conn = call(req, opts)
      assert_receive :done

      assert conn.status == 500
      error = Jason.decode!(conn.resp_body)
      assert error["code"] == "internal"
    end

    test "catches exceptions raised in other before hooks" do
      us = self()
      bad_hook = fn _, _ ->
        raise ArgumentError, "Thrown from hook"
      end
      bad_success_hook = fn _env ->
        raise ArgumentError, "Thrown from success"
      end

      exception_hook = fn env, exception ->
        assert Norm.valid?(env, Twirp.Plug.env_s())
        assert match?(%ArgumentError{}, exception)
        send us, :done
      end

      opts = Twirp.Plug.init [
        service: Service,
        handler: GoodHandler,
        before: [bad_hook],
        on_exception: [exception_hook],
      ]
      req = proto_req("MakeHat", Size.new(inches: 10))
      _conn = call(req, opts)
      assert_receive :done

      opts = Twirp.Plug.init [
        service: Service,
        handler: GoodHandler,
        on_success: [bad_success_hook],
        on_exception: [exception_hook],
      ]
      req = proto_req("MakeHat", Size.new(inches: 10))
      _conn = call(req, opts)
      assert_receive :done
    end
  end
end
