defmodule Twirp.Plug do
  @moduledoc """
  Provides a plug that takes service and handler module. If the request is
  directed at the "twirp" endpoint then the plug will intercept the conn and
  process it. Otherwise it allows the conn to pass through. This is a deviation
  from the twirp specification but it allows users to include twirp services
  into their existing plug stacks.

  You can use the plug like so:

  ```elixir
  plug Twirp.Plug,
    service: MyService,
    handler: MyHandler,
  ```
  """

  @content_type "content-type"

  alias Twirp.Encoder
  alias Twirp.Error

  import Plug.Conn
  import Norm

  def env_s do
    schema(%{
      content_type: spec(is_binary()),
      method_name: spec(is_atom()),
      handler_fn: spec(is_atom()),
      input: spec(is_map()),
      input_type: spec(is_atom()),
      output_type: spec(is_atom()),
      http_response_headers: map_of(spec(is_binary()), spec(is_binary())),
    })
  end

  def init([service: service_mod, handler: handler]) when is_atom(service_mod) and is_atom(handler) do
    service_def =
      service_mod.definition()
      |> Norm.conform!(Twirp.Service.s())

    rpc_defs =
      for rpc <- service_def.rpcs,
        do: {"#{rpc.method}", rpc},
        into: %{}

    service_def =
      service_def
      |> Map.put(:rpcs, rpc_defs)
      |> Map.put(:full_name, Twirp.Service.full_name(service_def))

    {service_def, handler}
  end

  def call(%{path_info: ["twirp", full_name, method]}=conn, {%{full_name: full_name}=service, handler}) do
    with {:ok, env} <- validate_req(conn, method, service),
         {:ok, env, conn} <- get_input(env, conn),
         {:ok, output} <- call_handler(handler, env)
    do
      # We're safe to just get the output because call_handler has handled
      # the error case for us
      resp = Encoder.encode(output, env.output_type, env.content_type)

      conn
      |> put_resp_content_type(env.content_type)
      |> send_resp(200, resp)
      |> halt()
    else
      {:error, error} ->
        send_error(conn, error)
    end
  end

  def call(conn, _opts) do
    conn
  end

  def validate_req(conn, method, %{rpcs: rpcs}) do
    content_type = content_type(conn)

    cond do
      conn.method != "POST" ->
        {:error, bad_route("HTTP request must be POST", conn)}

      !Encoder.valid_type?(content_type) ->
        {:error, bad_route("Unexpected Content-Type: #{content_type || "nil"}", conn)}

      rpcs[method] == nil ->
        {:error, bad_route("Invalid rpc method: #{method}", conn)}

      true ->
        rpc = rpcs[method]

        env = %{
          content_type: content_type,
          http_response_headers: %{},
          method_name: rpc.method,
          input_type: rpc.input,
          output_type: rpc.output,
          handler_fn: rpc.handler_fn,
        }

        {:ok, conform!(env, env_s())}
    end
  end

  defp get_input(env, conn) do
    with {:ok, body, conn} <- get_body(conn, env),
         {:decoding, {:ok, decoded}} <- {:decoding, Encoder.decode(body, env.input_type, env.content_type)} do
      {:ok, Map.put(env, :input, decoded), conn}
    else
      {:decoding, _} ->
        msg = "Invalid request body for rpc method: #{env.method_name}"
        error = bad_route(msg, conn)
        {:error, error}
    end
  end

  defp get_body(conn, env) do
    # If we're in a phoenix endpoint or an established plug router than the
    # user is probably already using a plug parser and the body will be
    # empty. We need to check to see if we have body params which is an
    # indication that our json has already been parsed. Limiting this to
    # only json payloads since the user most likely doesn't have a protobuf
    # parser already set up and I want to limit this potentially surprising
    # behaviour.
    if Encoder.json?(env.content_type) and body_params?(conn) do
      {:ok, conn.body_params, conn}
    else
      case apply(Plug.Conn, :read_body, [conn]) do
        {:ok, body, conn} ->
          {:ok, body, conn}

        _ ->
          {:error, Error.internal("req_body has already been read or is too large to read")}
      end
    end
  end

  defp body_params?(conn) do
    case conn.body_params do
      %Plug.Conn.Unfetched{} -> false
      _ -> true
    end
  end

  # TODO - Handle the case where rpc handlers raise exceptions
  defp call_handler(handler, %{output_type: output_type}=env) do
    env = conform!(env, selection(env_s()))

    if function_exported?(handler, env.handler_fn, 2) do
      case apply(handler, env.handler_fn, [env, env.input]) do
        %Error{}=error ->
          {:error, error}

        %{__struct__: s}=resp when s == output_type ->
          {:ok, resp}

        other ->
          msg = "Handler method #{env.handler_fn} expected to return one of #{env.output_type} or Twirp.Error but returned #{inspect other}"
          {:error, Error.internal(msg)}
      end
    else
      {:error, Error.unimplemented("Handler function #{env.handler_fn} is not implemented")}
    end
  rescue
    exception ->
      {:error, Error.internal(Exception.message(exception))}
  end

  defp content_type(conn) do
    Enum.at(get_req_header(conn, @content_type), 0)
  end

  defp send_error(conn, error) do
    content_type = Encoder.type(:json)
    body = Encoder.encode(error, nil, content_type)

    conn
    |> put_resp_content_type(content_type)
    |> send_resp(Error.code_to_status(error.code), body)
    |> halt()
  end

  defp bad_route(msg, conn) do
    Error.bad_route(msg, twirp_invalid_route: "#{conn.method} #{conn.request_path}")
  end
end
