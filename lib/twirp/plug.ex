defmodule Twirp.Plug do
  import Plug.Conn

  @json "application/json"
  @proto "application/proto"
  @valid_content_types [@json, @proto]


end
