defmodule Twirp.Encoder do
  @json "application/json"
  @proto "application/proto"
  @valid_types [@json, @proto]

  def valid_type?([]), do: false
  def valid_type?([type]) when type in @valid_types, do: true
  def valid_type?(type) when type in @valid_types, do: true

  def decode(bytes, input, @json) do
    # TODO - Write tests for atoms! failing and for decoding failing
    # TODO - Do better validation of json input
    payload = Jason.decode!(bytes, keys: :atoms!)
    {:ok, input.new(payload)}
  end

  def encode(payload, _output, @json) do
    payload
    |> Jason.encode!
  end
end

