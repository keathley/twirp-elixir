defmodule Twirp.Client do
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

    service_path = Path.join(["twirp", service.package, service.service])

    fs_to_define =
      Enum.map(rpcs, fn r ->
        quote do
          def unquote(r.handler_fn)(client, %unquote(r.input){}=req) do
            rpc(
              client,
              unquote(r.method),
              unquote(r.input),
              unquote(r.output),
              req
            )
          end
        end
      end)

    quote do
      # TODO - This should also allow you to configure the adapter
      # Maybe we should allow people to pass in the client or whatever as well.
      def client(base_url, middleware) when is_binary(base_url) do
        base_middleware = [
          {Tesla.Middleware.BaseUrl, base_url},
          {Tesla.Middleware.Headers, [{"Content-Type", "application/proto"}]},
        ]

        Tesla.client(middleware ++ base_middleware, Tesla.Adapter.Hackney)
      end

      def rpc(client, method, input, output, req) do
        rpc = unquote(Macro.escape(rpc_map))[method]

        if rpc do
          Twirp.Client.HTTP.make_rpc(
            client,
            unquote(service_path),
            method,
            input,
            output,
            req
          )
        else
          {:error, Twirp.Error.bad_route("rpc not defined on this client")}
        end
      end

      # def rpc(client, method, input, output) do
      #   rpc = Enum.find(unquote(rpcs), fn rpc -> rpc.method == method end)

      #   if rpc do
      #     # Twirp.Client.HTTP.rpc(
      #     #   client,
      #     #   unquote(service_path),
      #     #   input,
      #     #   output
      #     # )
      #   else
      #     {:error, Error.bad_route("rpc not defined on this client")}
      #   end
      # end

      unquote(fs_to_define)
    end
  end
end
