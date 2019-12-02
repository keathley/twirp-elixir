defmodule Twirp.Plug.ParsersTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias Twirp.Error

  defmodule Service do
    use Twirp.Service

    package "plug.test"
    service "Haberdasher"

    rpc :MakeHat, Size, Hat, :make_hat
  end

  defmodule Handler do
    def make_hat(_env, %Size{inches: inches}) do
      if inches <= 0 do
        Error.invalid_argument("I can't make a hat that small!")
      else
        %Hat{color: "red"}
      end
    end
  end

  defmodule Client do
    use Twirp.Client, service: Service
  end

  defmodule TestRouter do
    use Plug.Router

    plug Plug.Parsers, parsers: [:urlencoded, :json],
      pass: ["text/*"],
      json_decoder: Jason

    plug Twirp.Plug,
      service: Service,
      handler: Handler

    plug :match

    match _ do
      send_resp(conn, 404, "oops")
    end
  end

  @opts TestRouter
  # @opts Twirp.Plug.init([service: Service, handler: GoodHandler])

  test "returns correctly if the body has already been parsed" do

  end
end
