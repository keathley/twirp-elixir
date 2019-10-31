defmodule Twirp.Encoder do
  @json "application/json"
  @proto "application/proto"
  @valid_types [@json, @proto]

  def valid_type?([]), do: false
  def valid_type?([type]) when type in @valid_types, do: true
  def valid_type?(type) when type in @valid_types, do: true
  def valid_type?(_), do: false

  def json_type, do: @json

  def proto?(content_type), do: content_type == @proto

  def decode(bytes, input, @json <> _) do
    # TODO - Write tests for atoms! failing and for decoding failing
    # TODO - Do better validation of json input
    payload = Jason.decode!(bytes, keys: :atoms!)
    {:ok, input.new(payload)}
  end

  def decode(bytes, input, @proto <> _) do
    payload = input.decode(bytes)

    {:ok, payload}
  end

  def decode_json(bytes) do
    Jason.decode(bytes)
  end

  def encode(payload, _output, @json <> _) do
    payload
    |> Jason.encode!
  end

  def encode(payload, output, @proto <> _) do
    output.encode(payload)
  end
end

