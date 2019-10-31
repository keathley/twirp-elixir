defmodule Twirp.ClientTest do
  use ExUnit.Case, async: true

  defmodule Req do
    use Protobuf, syntax: :proto3

    @derive Jason.Encoder
    defstruct [:msg]

    field :msg, 1, type: :string
  end

  defmodule Resp do
    use Protobuf, syntax: :proto3

    @derive Jason.Encoder
    defstruct [:msg]

    field :msg, 1, type: :string
  end

  defmodule Service do
    use Twirp.Service

    package "client.test"
    service "ClientTest"

    rpc :Echo, Req, Resp, :echo
  end

  defmodule Client do
    use Twirp.Client, service: Service
  end

  test "generated clients have rpc functions defined on them" do
    client = Twirp.Client.Mock.client()
    assert {:ok, %Resp{msg: "test"}} == Client.echo(client, Req.new(msg: "test"))
  end
end
