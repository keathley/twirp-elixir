defprotocol Twirp.Client.Callable do
  def call(client, rpc, req, opts)
end

