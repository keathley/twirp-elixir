defmodule Twirp.Client.HTTP do
  @moduledoc false
  # This module handles the internals of making RPC calls. We delegate to this
  # from the actual client module cuz otherwise the client module is a pita
  # to understand due to the macros and functions its creating.
  alias Twirp.Encoder
  alias Twirp.Error

  @default_opts [timeout: 1_000]

  defstruct [name: nil, service_url: nil, headers: []]

  def new(name, url, headers) do
    %__MODULE__{name: name, service_url: url, headers: headers}
  end

  def call(client, rpcdef, req, opts) do
    path            = "#{client.service_url}/#{rpcdef.method}"
    content_type    = req_content_type(client)
    encoded_payload = Encoder.encode(req, rpcdef.input, content_type)
    opts            = Keyword.merge(@default_opts, opts)

    case Finch.request(client.name, :post, path, client.headers, encoded_payload, opts) do
      {:error, %{reason: :timeout}} ->
        meta = %{error_type: "timeout"}
        msg = "Deadline to receive data from the service was exceeded"
        {:error, Error.deadline_exceeded(msg, meta)}

      {:error, %Mint.TransportError{reason: reason}} ->
        meta = %{error_type: "#{reason}"}
        {:error, Error.unavailable("Service is down", meta)}

      {:ok, %{status: status}=env} when status != 200 ->
        {:error, build_error(env, rpcdef)}

      {:ok, %{status: 200}=env} ->
        handle_success(env, rpcdef, content_type)
    end
  end

  def handle_success(env, rpcdef, content_type) do
    resp_content_type = resp_header(env, "content-type")

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
        meta = %{
          http_error_from_intermediary: "true",
          not_a_twirp_error_because: "Redirects not allowed on Twirp requests",
          status_code: Integer.to_string(status),
          location: location,
        }
        msg = "Unexpected HTTP Redirect from location=#{location}"
        Error.internal(msg, meta)

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

  defp resp_header(resp, header) do
    case Enum.find(resp.headers, fn {h, _} -> h == header end) do
      {^header, value} ->
        value

      _ ->
        nil
    end
  end

  defp req_content_type(client) do
    client.headers
    |> Enum.filter(fn {header, _} -> String.downcase(header) == "content-type" end)
    |> Enum.map(fn {_, type} -> type end)
    |> Enum.at(0)
  end
end
