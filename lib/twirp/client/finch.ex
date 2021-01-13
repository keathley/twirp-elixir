defmodule Twirp.Client.Finch do
  @moduledoc false
  alias Twirp.Client.AdapterError

  require Logger

  def start_link(opts) do
    if Code.ensure_loaded?(Finch) do
      opts = Keyword.new(opts)
      Finch.start_link(opts)
    else
      raise AdapterError, :finch
    end
  end

  def request(client, ctx, path, payload) do
    # The connect_timeout here doesn't exist in finch as of version 0.6.
    # I'm including it here so that it'll work once this timeout gets added
    # in.
    opts    = [
      pool_timeout: ctx[:connect_deadline] || 1_000,
      connect_timeout: ctx[:connect_deadline] || 1_000,
      receive_timeout: ctx.deadline,
    ]
    request = Finch.build(:post, path, ctx.headers, payload)
    Finch.request(request, client, opts)
  end
end
