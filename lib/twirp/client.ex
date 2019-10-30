defmodule Twirp.Client do
  defmacro __using__(opts) do
    quote do
      import Twirp.Client

      IO.inspect(unquote(opts), label: "Opts")
      @service_definition Keyword.get(unquote(opts), :service)

      IO.inspect(@service_definition, label: "Service def")

      @before_compile Twirp.Client
    end
  end

  # Build everything we need to be able to dispatch our rpcs correctly
  @doc false
  defmacro __before_compile__(env) do
    service = Module.get_attribute(env.module, :service_definition)
    rpcs = service.rpcs()

    service_path = Path.join(["twirp", service.package(), service.service()])

    fs_to_define =
      Enum.map(rpcs, fn rpc ->
        quote do
          def unquote(rpc.f)(client, %unquote(rpc.input){}=req) do
            Twirp.Client.HTTP.make_rpc(
              client,
              unquote(service_path),
              unquote(rpc.method),
              unquote(rpc.output),
              req
            )
          end
        end
      end)

    quote do
      # TODO - This should also allow you to configure the adapter
      # Maybe we should allow people to pass in the client or whatever as well.
      def new(base_url, middleware) when is_binary(base_url) do
        base_middleware = [
          {Tesla.Middleware.BaseUrl, base_url},
          {Tesla.Middleware.Headers, [{"Content-Type", "application/proto"}]},
          Tesla.Middleware.Logger,
        ]

        Tesla.client(base_middleware ++ middleware, Tesla.Adapter.Hackney)
      end

      unquote(fs_to_define)
    end
  end
end
