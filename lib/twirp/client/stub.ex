defmodule Twirp.Client.StubError do
  @moduledoc false
  defexception [:message]

  def exception(e) do
    %__MODULE__{message: msg(e)}
  end

  defp msg({:not_defined, f}) do
    "Stub does not define #{f}/1"
  end
  defp msg({:wrong_return, rpc, out}) do
    correct_output =
      rpc.output
      |> Atom.to_string
      |> String.trim_leading("Elixir.")

    "Stub was expected to return %#{correct_output}{} or %Twirp.Error{} but returned: #{inspect out}"
  end
end

defmodule Twirp.Client.Stub do
  @moduledoc """
  Provides a stub client implementation. This allows users to stub out responses
  from a service for development and testing.
  """
  defstruct [methods: []]

  def new(methods \\ []) do
    %__MODULE__{methods: methods}
  end

  defimpl Twirp.Client.Callable do
    def call(client, rpc, req, _opts) do
      if rpc.handler_fn in Keyword.keys(client.methods) do
        output_type = rpc.output
        f = client.methods[rpc.handler_fn]

        case f.(req) do
          %Twirp.Error{}=error -> {:error, error}

          %^output_type{}=out ->
            {:ok, out}

          out ->
            raise Twirp.Client.StubError, {:wrong_return, rpc, out}
        end
      else
        raise Twirp.Client.StubError, {:not_defined, rpc.handler_fn}
      end
    end
  end
end
