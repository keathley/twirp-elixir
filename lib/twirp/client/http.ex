defmodule Twirp.Client.HTTP do
  alias Twirp.Encoder

  alias Twirp.Error

  def call(client, base_path, rpcdef, req, opts \\ []) do
    path = "#{base_path}/#{rpcdef.method}"

    opts = build_hackney_opts(opts)

    content_type = req_content_type(client)
    encoded_payload = Encoder.encode(req, rpcdef.input, content_type)

    case Tesla.post(client, path, encoded_payload, [opts: opts]) do
      {:error, :timeout} ->
        meta = %{
          timeout: Integer.to_string(get_in(opts, [:adapter, :recv_timeout]))
        }
        {:error, Error.deadline_exceeded("Deadline to receive data from the service was exceeded", meta)}

      {:error, :econnrefused} ->
        {:error, Error.unavailable("Service is down")}

      {:ok, %{status: status}=env} when status != 200 ->
        {:error, build_error(env, rpcdef)}

      {:ok, %{status: 200}=env} ->
        handle_success(env, rpcdef, content_type)

      other ->
        {:error, Error.internal("unhandled response after making RPC POST: #{inspect other}")}
    end
  end

  def handle_success(env, rpcdef, content_type) do
    resp_content_type = resp_header(env, "content-type")

    # TODO - Figure out how to unify these ideas between client and service
    if resp_content_type && String.starts_with?(resp_content_type, content_type) do
      Encoder.decode(env.body, rpcdef.output, content_type)
    else
      {:error, Error.internal(~s|Expected response Content-Type "#{content_type}" but found #{resp_content_type || "nil"}|)}
    end
  end

  def build_error(resp, _rpcdef) do
    status = resp.status

    cond do
      http_redirect?(status) ->
        location = resp_header(resp, "location")
        redirect_error(location)

      true ->
        case Encoder.decode_json(resp.body) do
          {:ok, %{"code" => code, "msg" => msg}=error} ->
            if Error.valid_code?(code) do
              # Its safe to convert to an atom here since all the codes are already
              # created and loaded. If we explode we explode.
              Error.new(String.to_existing_atom(code), msg, error["meta"] || %{})
            else
              Error.internal("Invalid Twirp error code: #{code}", invalid_code: code, body: resp.body)
            end

          {:ok, _} ->
            msg = "Response is JSON but it has no \"code\" attribute"
            intermediary_error(status, msg, resp.body)

          {:error, _} ->
            intermediary_error(status, "Response is not JSON", resp.body)
        end
    end
  end

  defp redirect_error(location) do
    meta = %{
      http_error_from_intermediary: "true",
      not_a_twirp_error_because: "Redirects not allowed on Twirp requests",
      status_code: Integer.to_string(status),
      location: location,
    }
    msg = "Unexpected HTTP Redirect from location=#{location}"

    Error.internal(msg, meta)
  end

  defp intermediary_error(status, reason, body) do
    meta = %{
      http_error_from_intermediary: "true",
      not_a_twirp_error_because: reason,
      status_code: Integer.to_string(status),
      body: body
    }

    case status do
      400 -> Error.internal("internal", meta)
      401 -> Error.unauthenticated("unauthenticated", meta)
      403 -> Error.permission_denied("permission denied", meta)
      404 -> Error.bad_route("bad route", meta)
      s when s in [429, 502, 503, 504] -> Error.unavailable("unavailable", meta)
      _ -> Error.unknown("unknown", meta)
    end
  end

  defp http_redirect?(status) do
    300 <= status && status <= 399
  end

  # TODO - Unify this betweeen client and service
  defp resp_header(resp, header) do
    case Enum.find(resp.headers, fn {h, _} -> h == header end) do
      {^header, value} ->
        value

      _ ->
        nil
    end
  end

  defp req_content_type(client) do
    client.pre
    |> Enum.filter(fn pre -> match?({Tesla.Middleware.Headers, _, _}, pre) end)
    |> Enum.flat_map(fn {_, _, [args]} -> args end)
    |> Enum.filter(fn {header, _} -> String.downcase(header) == "content-type" end)
    |> Enum.map(fn {_, type} -> type end)
    |> Enum.at(0)
  end

  defp build_hackney_opts(opts) do
    case Keyword.get(opts, :timeout) do
      nil ->
        [adapter: [recv_timeout: 1_000]]

      val when is_integer(val) ->
        [adapter: [recv_timeout: val]]
    end
  end
end
