defmodule Twirp.Service do
  defmacro __using__(_opts) do
    quote do
      import Twirp.Service

      @rpcs []

      @before_compile Twirp.Service
    end
  end

  defmacro package(str) do
    quote do
      @package unquote(str)
    end
  end

  defmacro service(str) do
    quote do
      @service unquote(str)
    end
  end

  defmacro rpc(method, input, output, f) do
    quote do
      rpc = %{
        method: unquote(method),
        input: unquote(input),
        output: unquote(output),
        handler_fn: unquote(f)
      }

      @rpcs [rpc | @rpcs]
    end
  end

  # Build everything we need to be able to dispatch our rpcs correctly
  @doc false
  defmacro __before_compile__(_env) do
    quote do
      def definition do
        %{
          package: @package,
          service: @service,
          rpcs: @rpcs
        }
      end
    end
  end
end

