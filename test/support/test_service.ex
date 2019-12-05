defmodule Twirp.TestService do
  @moduledoc false

  defmodule Req do
    @moduledoc false
    use Protobuf, syntax: :proto3

    @derive Jason.Encoder
    defstruct [:msg]

    field :msg, 1, type: :string
  end

  defmodule ReqNoJsonProtocol do
    @moduledoc false
    use Protobuf, syntax: :proto3

    defstruct [:msg, :sub]

    field :msg, 1, type: :string
    field :sub, 2, type: ReqSub
  end

  defmodule ReqSub do
    @moduledoc false

    use Protobuf, syntax: :proto3

    defstruct [:msg]

    field :msg, 1, type: :string
  end

  defmodule Resp do
    @moduledoc false
    use Protobuf, syntax: :proto3

    @derive Jason.Encoder
    defstruct [:msg]

    field :msg, 1, type: :string
  end

  defmodule Service do
    @moduledoc false
    use Twirp.Service

    package "client.test"
    service "ClientTest"

    rpc :Echo, Req, Resp, :echo
    rpc :SlowEcho, Req, Resp, :slow_echo
  end

  defmodule Client do
    @moduledoc false
    use Twirp.Client, service: Service
  end

  defmodule Handler do
    @moduledoc false
    def echo(_conn, %Req{msg: msg}) do
      %Resp{msg: msg}
    end

    def slow_echo(_conn, %Req{msg: msg}) do
      :timer.sleep(50)
      %Resp{msg: msg}
    end
  end
end
