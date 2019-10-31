defmodule Twirp.Plug do
  import Plug.Conn

  alias Twirp.Encoder
  alias Twirp.Error

  @content_type "content-type"

  def init([service: service_mod, handler: handler]) do
    # Check that these conform with norm
    {service_mod.definition(), handler}
  end

  def call(conn, {%{service: service, package: package, rpcs: rpcs}, handler}) do
    rpcs =
      for rpc <- rpcs,
        do: {"#{rpc.method}", rpc},
        into: %{}

    # TODO - Pull package and service from the service definition.
    with ["twirp", ^package, ^service, method] <- conn.path_info,
         "POST" <- conn.method,
         [content_type] = get_req_header(conn, @content_type),
         true <- Encoder.valid_type?(content_type)
    do
      # TODO - Make this safe
      {:ok, body, conn} = apply(Plug.Conn, :read_body, [conn])
      rpc = rpcs[method]
      env = %{}

      if rpc do
        case Encoder.decode(body, rpc.input, content_type) do
          {:ok, input} ->
            case apply(handler, rpc.handler_fn, [env, input]) do
              %Error{}=error ->
                content_type = Encoder.json_type()
                body = Encoder.encode(error, nil, content_type)

                conn
                |> put_resp_content_type(content_type)
                |> send_resp(Error.code_to_status(error.code), body)
                |> halt()

              result ->
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
        end
      else

      end
    else
      _ ->
        conn
    end
  end
end

