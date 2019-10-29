defmodule Twirp.ServiceTest do
  use ExUnit.Case, async: true

  defmodule Req do
    def new(input) do
      Enum.into(input, %{})
    end
  end

  defmodule Resp do
    def new(input) do
      Enum.into(input, %{})
    end
  end

  defmodule TestService do
    use Twirp.Service

    rpc :Foo, Req, Resp, to: :foo
  end

  test "" do
  end
end
