defmodule Twirp.Client.Adapter do
  @callback call(term(), term(), term(), term()) :: term()
end
