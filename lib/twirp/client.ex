defmodule Twirp.Client do
  @moduledoc """
  Provides a macro for generating clients based on service definitions.
  """

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

    callbacks =
      Enum.map(rpcs, fn r ->
        quote do
          @callback unquote(r.handler_fn)(term(), unquote(r.input)) :: {:ok, unquote(r.output)} | {:error, %Twirp.Error{}}
        end
      end)

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
      unquote(callbacks)

      def start(adapter_opts \\ []) do
        default_opts = [
          timeout: 150_000,
          max_connections: 60
        ]

        opts = Keyword.merge(default_opts, Keyword.take(adapter_opts, [:timeout, :max_connections]))
               # |> IO.inspect(label: "Pool options")
        name = Keyword.get(adapter_opts, :pool_name, __MODULE__.Pool)

        :hackney_pool.start_pool(name, opts)
      end

      # TODO - This should also allow you to configure the adapter
      # Maybe we should allow people to pass in the client or whatever as well.
      def client(content_type \\ :proto, base_url, middleware, adapter_opts) when is_binary(base_url) do
        base_middleware = [
          {Tesla.Middleware.BaseUrl, base_url},
          {Tesla.Middleware.Headers, [{"Content-Type", Twirp.Encoder.type(content_type)}]},
        ]

        default_adapter_opts = [
          recv_timeout: 1_000,
          pool: __MODULE__.Pool,
          connect_timeout: 500
        ]

        adapter_opts = Keyword.merge(default_adapter_opts, adapter_opts)
                       # |> IO.inspect(label: "Adapter options")

        Tesla.client(middleware ++ base_middleware, {Tesla.Adapter.Hackney, adapter_opts})
      end

      def rpc(client, method, req, opts \\ []) do
        rpcdef = unquote(Macro.escape(rpc_map))[method]

        if rpcdef do
          Twirp.Client.HTTP.call(
            client,
            unquote(service_path),
            rpcdef,
            req,
            opts
          )
        else
          {:error, Twirp.Error.bad_route("rpc not defined on this client")}
        end
      end

      unquote(fs_to_define)
    end
  end
end
