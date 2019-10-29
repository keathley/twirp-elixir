defmodule Twirp.PlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  @opts Twirp.Plug.init([])

  test "only works with POST" do
    conn = conn(:post, "/twirp/twirp.test.package/tester/Test")
    conn = Twirp.Plug.call(conn, @opts)

    assert conn.status == 200

    conn = conn(:get, "/twirp/twirp.test.package/tester/Test")
    conn = Twirp.Plug.call(conn, @opts)

    assert conn.status == 404
  end

  test "incorrect routes" do
    flunk "Not Implemented"
  end
end
