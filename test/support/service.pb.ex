defmodule Twirp.Test.Envelope do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          msg: String.t(),
          sub: Twirp.Test.Req.t() | nil
        }

  defstruct [:msg, :sub]

  field :msg, 1, type: :string
  field :sub, 2, type: Twirp.Test.Req
end

defmodule Twirp.Test.Req do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          msg: String.t()
        }

  defstruct [:msg]

  field :msg, 1, type: :string
end

defmodule Twirp.Test.Resp do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          msg: String.t()
        }

  defstruct [:msg]

  field :msg, 1, type: :string
end

defmodule Twirp.Test.BatchReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          requests: [Twirp.Test.Req.t()]
        }

  defstruct [:requests]

  field :requests, 1, repeated: true, type: Twirp.Test.Req
end

defmodule Twirp.Test.BatchResp do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          responses: [Twirp.Test.Resp.t()]
        }

  defstruct [:responses]

  field :responses, 1, repeated: true, type: Twirp.Test.Resp
end
