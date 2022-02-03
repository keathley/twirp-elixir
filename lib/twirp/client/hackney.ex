defmodule Twirp.Client.Hackney do
  @moduledoc false
  alias Twirp.Client.AdapterError

  def start_link(opts) do
    if Code.ensure_loaded?(:hackney) do
      try do
        pool_opts = opts[:pool_opts] || [{:timeout, 30_000}, {:max_connections, 100}]
        :hackney_pool.start_pool(opts.name, pool_opts)
        :ignore
      catch
        _, _ ->
          # This can fail if the pool is already started.
          :ignore
      end
    else
      raise AdapterError, :hackney
    end
  end

  def request(client, ctx, path, payload) do
    options = [
      pool: client,
      connect_timeout: ctx[:connect_deadline] || 1_000,
      checkout_timeout: ctx[:connect_deadline] || 1_000,
      recv_timeout: ctx.deadline,
    ]

    with {:ok, status, headers, ref} <- :hackney.request(:post, path, ctx.headers, payload, options),
         {:ok, body} <- :hackney.body(ref) do
      {:ok, %{status: status, headers: format_headers(headers), body: body}}
    else
      {:error, :timeout} ->
        {:error, %{reason: :timeout}}

      {:error, :checkout_timeout} ->
        {:error, %{reason: :timeout}}

      {:error, :econnrefused} ->
        {:error, %{reason: :econnrefused}}

      error ->
        error
    end
  end

  defp format_headers(headers) do
    for {key, value} <- headers do
      {String.downcase(to_string(key)), to_string(value)}
    end
  end
end
