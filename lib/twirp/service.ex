defmodule Twirp.Service do
  defmacro __using__(_opts) do
    quote do
      import Twirp.Service

      @rpcs []

      @before_compile Twirp.Service
    end
  end

  # defmacro package(str) do

  # end

  # defmacro service(str) do

  # end

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

      @json "application/json"
      @proto "application/proto"
      @valid_content_types [@json, @proto]

      def init(options) do
        options
        |> IO.inspect(label: "Plug init")
      end

      def call(conn, options) do
        # TODO - Pull package and service from the service definition.
        with ["twirp", package, service, method] <- conn.path_info,
             "POST" <- conn.method do
          # TODO - Make this use atoms and do a reverse lookup
          rpc = Enum.find(@rpcs, fn rpc -> rpc.method == method end)
          result = apply(options[:handler], rpc.f, [conn, %{inches: 123}])
          IO.inspect(result, label: "Result")

        # TODO - Pull encoding from content-type. decode into the actual struct
        # that we've been given
        # TODO - Move all encoding and decoding logic into a different module
         body =
           result
           |> Map.from_struct()
           |> Jason.encode!

          conn
          |> put_resp_content_type("application/json")
          |> send_resp(200, body)
          |> halt()
        else
          _ ->
            conn
        end
      end

      def valid_request(conn) do
        cond do
          conn.method != "POST" ->
            {:error, Twirp.Error.bad_route("HTTP request method must be POST")}

          !valid_content_type?(conn.get_req_header("content-type")) ->
            {:error, "content-type is wrong"}

          true ->
            {:ok, conn}
        end
      end

      def valid_content_type?([]), do: false
      def valid_content_type?([type]) when type in @valid_content_types, do: true

      # Twirp errors are always returned as json responses
      def error_response(conn, error) do
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, %{code: "bad_route", msg: "method must be POST"})
      end

      def rpcs do
        @rpcs
      end
    end
  end
end

