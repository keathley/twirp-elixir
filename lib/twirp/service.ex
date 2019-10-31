defmodule Twirp.Service do
  import Norm

  defmacro __using__(_opts) do
    quote do
      import Twirp.Service

      @rpcs []

      @before_compile Twirp.Service
    end
  end

  def s do
    schema(%{
      package: spec(is_binary()),
      service: spec(is_binary()),
      rpcs: coll_of(rpc_s())
    })
  end

  def rpc_s do
    schema(%{
      method: spec(is_atom()),
      input: spec(is_atom()),
      output: spec(is_atom()),
      handler_fn: spec(is_atom()),
    })
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
        conform!(%{package: @package, service: @service, rpcs: @rpcs}, s())
      end
    end
  end
end

