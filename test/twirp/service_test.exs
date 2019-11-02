defmodule Twirp.ServiceTest do
  use ExUnit.Case, async: false

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

    package "test.service"
    service "TestService"
    rpc :Foo, Req, Resp, :foo
  end

  test "DSL adds definition/0 fn to service module" do
    assert TestService.definition() == %{
      package: "test.service",
      service: "TestService",
      rpcs: [
        %{method: :Foo, input: Req, output: Resp, handler_fn: :foo}
      ]
    }
  end
end
