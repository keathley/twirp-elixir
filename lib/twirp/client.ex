defmodule Twirp.Client do
  @moduledoc """
  Provides a macro for generating clients based on service definitions.
  """

  alias Twirp.Client.HTTP
  alias Twirp.Client.Callable

  defmacro __using__(opts) do
    quote do
      import Twirp.Client

      @service_definition Keyword.get(unquote(opts), :service).definition()

      @before_compile Twirp.Client
    end
  end

  # Build everything we need to be able to dispatch our rpcs correctly
  @doc false
  defmacro __before_compile__(env) do
    service = Module.get_attribute(env.module, :service_definition)
    rpcs = service.rpcs
    rpc_map = for rpc <- rpcs, do: {rpc.method, rpc}, into: %{}

    service_path = Path.join(["twirp", "#{service.package}.#{service.service}"])

    fs_to_define =
      Enum.map(rpcs, fn r ->
        quote do
          # TODO - Clean up this pattern match / error handling
          def unquote(r.handler_fn)(client, %unquote(r.input){}=req, opts \\ []) do
            rpc(
              client,
              unquote(r.method),
              req,
              opts
            )
          end
        end
      end)

    quote do
      # TODO - This should also allow you to configure the adapter
      # Maybe we should allow people to pass in the client or whatever as well.
      def new(content_type, host_url, headers \\ []) when is_binary(host_url) do
        headers = [
          {"Content-Type", Twirp.Encoder.type(content_type)} | headers
        ]

        service_url = "#{host_url}/#{unquote(service_path)}"

        HTTP.new(service_url, headers)
      end

      def rpc(client, method, req, opts \\ []) do
        rpcdef = unquote(Macro.escape(rpc_map))[method]

        if rpcdef do
          Callable.call(client, rpcdef, req, opts)
        else
          {:error, Twirp.Error.bad_route("rpc not defined on this client")}
        end
      end

      unquote(fs_to_define)
    end
  end
end
