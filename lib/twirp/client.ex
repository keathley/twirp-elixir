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

    fs_to_define =
      Enum.map(rpcs, fn rpc ->
        quote bind_quoted: [name: rpc.f] do
          def name(%unquote(rpc.input){}=req) do
            Tesla.Client.HTTP.post(
          end
        end
      end)

    quote do
      unquote(fs_to_define)

      def rpc(name, req) do
        IO.puts "Making an rpc: #{name}, #{inspect req}"
      end
    end
  end
end
