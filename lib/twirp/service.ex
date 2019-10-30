defmodule Twirp.Service do
  alias Twirp.Encoder

  defmacro __using__(_opts) do
    quote do
      import Twirp.Service

      @rpcs []

      @before_compile Twirp.Service
    end
  end

  defmacro package(str) do
    quote do
      @package unquote(str)
    end
  end

  defmacro service(str) do
    quote do
      @service unquote(str)
    end
  end

  defmacro rpc(method, input, output, f) do
    quote do
      rpc = %{
        method: unquote(method),
        input: unquote(input),
        output: unquote(output),
        f: unquote(f)
      }

      @rpcs [rpc | @rpcs]
    end
  end

  # Build everything we need to be able to dispatch our rpcs correctly
  @doc false
  defmacro __before_compile__(_env) do
    quote do
      import Plug.Conn

      @content_type "content-type"
      @rpcs for rpc <- @rpcs, do: {Atom.to_string(rpc.method), rpc}, into: %{}

      def init(options) do
        options
        |> IO.inspect(label: "Plug init")
      end

      def call(conn, options) do
        # TODO - Pull package and service from the service definition.
        with ["twirp", @package, @service, method] <- conn.path_info,
             "POST" <- conn.method,
             [content_type] = get_req_header(conn, @content_type),
             true <- Encoder.valid_type?(content_type)
        do
          # TODO - Make this safe
          {:ok, body, conn} = apply(Plug.Conn, :read_body, [conn])
          rpc = @rpcs[method]
          env = %{}

          if rpc do
            case Encoder.decode(body, rpc.input, content_type) do
              {:ok, input} ->
                result = apply(options[:handler], rpc.f, [env, input])
                # TODO - Pull encoding from content-type. decode into the actual struct
                # that we've been given
                # TODO - Move all encoding and decoding logic into a different module
                body =
                  result
                  |> Encoder.encode(rpc.output, content_type)

                conn
                |> put_resp_content_type(content_type)
                |> send_resp(200, body)
                |> halt()
            end
          else

          end
        else
          _ ->
            conn
        end
      end

      # Twirp errors are always returned as json responses
      def error_response(conn, error) do
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, %{code: "bad_route", msg: "method must be POST"})
      end

      def rpcs do
        for {_, rpc} <- @rpcs, do: rpc
      end

      def package, do: @package

      def service, do: @service
    end
  end
end

