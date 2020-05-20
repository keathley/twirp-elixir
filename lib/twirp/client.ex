defmodule Twirp.Client do
  @moduledoc """
  Provides a macro for generating clients based on service definitions.
  """

  alias Twirp.Client.HTTP

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
          def unquote(r.handler_fn)(%unquote(r.input){}=req, headers \\ [], opts \\ []) do
            rpc(
              unquote(r.method),
              req,
              headers,
              opts
            )
          end
        end
      end)

    quote do

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]}
        }
      end

      def start_link(opts) do
        url = opts[:url] || raise ArgumentError, "Twirp Client requires a `:url` option"
        content_type = opts[:content_type] || :proto

        # TODO - Make pool configuration optional
        pool_config = %{
          default: [size: 10, count: 1]
        }

        :persistent_term.put({__MODULE__, :url}, url)
        :persistent_term.put({__MODULE__, :content_type}, content_type)
        Finch.start_link(name: __MODULE__, pools: pool_config)
      end

      def rpc(method, req, headers \\ [], opts \\ []) do
        rpcdef       = unquote(Macro.escape(rpc_map))[method]
        url          = :persistent_term.get({__MODULE__, :url})
        content_type = :persistent_term.get({__MODULE__, :content_type})
        service_url  = "#{url}/#{unquote(service_path)}"
        headers      = [
          {"Content-Type", Twirp.Encoder.type(content_type)} | headers
        ]

        client = HTTP.new(__MODULE__, service_url, headers)

        if rpcdef do
          HTTP.call(client, rpcdef, req, opts)
        else
          {:error, Twirp.Error.bad_route("rpc not defined on this client")}
        end
      end

      unquote(fs_to_define)
    end
  end
end
