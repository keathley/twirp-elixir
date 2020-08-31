defmodule Twirp.Encoder do
  @moduledoc false
  # Encodes and Decodes messages based on the requests content-type header.
  # For json we delegate to Jason. for protobuf responses we use the input or
  # output types.

  @json "application/json"
  @proto "application/protobuf"

  @valid_types [@json, @proto]

  def valid_type?([]), do: false
  def valid_type?([type]) when type in @valid_types, do: true
  def valid_type?(type) when type in @valid_types, do: true
  def valid_type?(_), do: false

  def type(:proto), do: @proto
  def type(:json), do: @json

  def proto?(content_type), do: content_type == @proto

  def json?(content_type), do: content_type == @json

  def decode(bytes, input, @json <> _) when is_binary(bytes) do
    # TODO - Write tests for atoms! failing and for decoding failing
    # TODO - Do better validation of json input
    case Jason.decode(bytes, keys: :atoms!) do
      {:ok, body} ->
        {:ok, input.new(body)}

      {:error, e} ->
        {:error, e}
    end
  end

  def decode(map, input, @json <> _) do
    case Jason.encode(map) do
      {:ok, bytes} ->
        decode(bytes, input, @json)

      {:error, e} ->
        {:error, e}
    end

    rescue
      e ->
        {:error, e}
  end

  def decode(bytes, input, @proto <> _) do
    payload = input.decode(bytes)

    {:ok, payload}
  catch
    :error, reason ->
      {:error, reason}
  end

  def decode_json(bytes) do
    Jason.decode(bytes)
  end

  def encode(payload, _output, @json <> _) do
    payload
    |> strip_structs()
    |> Jason.encode!
  end

  def encode(payload, output, @proto <> _) do
    output.encode(payload)
  end

  defp strip_structs(map) when is_map(map) do
    map
    |> Map.drop([:__struct__])
    |> Enum.into(%{}, fn {k,v} -> {k, strip_structs(v)} end)
  end

  defp strip_structs(any), do: any
end
