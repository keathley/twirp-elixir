defmodule Twirp.Error do
  @moduledoc """
  This module defines the different error codes as specified in
  https://twitchtv.github.io/twirp/docs/spec_v5.html#error-codes.

  We provide a function for each error code to that its easy for users to return
  errors in their handlers.
  """

  import Norm

  @error_code_to_http_status %{
    canceled:             408, # RequestTimeout
    invalid_argument:     400, # BadRequest
    deadline_exceeded:    408, # RequestTimeout
    not_found:            404, # Not Found
    bad_route:            404, # Not Found
    already_exists:       409, # Conflict
    permission_denied:    403, # Forbidden
    unauthenticated:      401, # Unauthorized
    resource_exhausted:   429, # Too Many Requests
    failed_precondition:  412, # Precondition Failed
    aborted:              409, # Conflict
    out_of_range:         400, # Bad Request

    internal:             500, # Internal Server Error
    unknown:              500, # Internal Server Error
    unimplemented:        501, # Not Implemented
    unavailable:          503, # Service Unavailable
    data_loss:            500, # Internal Server Error
  }

  @error_codes Map.keys(@error_code_to_http_status)
  @error_code_strings for code <- @error_codes, do: Atom.to_string(code)

  defexception ~w|code msg meta|a

  @type t :: %__MODULE__{
    code: atom(),
    msg: binary(),
    meta: %{atom() => binary()}
  }

  for code <- @error_codes do
    def unquote(code)(msg, meta \\ %{}) do
      new(unquote(code), msg, meta)
    end
  end

  def valid_code?(code) when is_atom(code), do: code in @error_codes
  def valid_code?(code) when is_binary(code), do: code in @error_code_strings

  def code_to_status(code) when code in @error_codes do
    @error_code_to_http_status[code]
  end

  def s do
    schema(%__MODULE__{
      code: spec(is_atom() and (& &1 in @error_codes)),
      msg: spec(is_binary()),
      meta: map_of(spec(is_binary()), spec(is_binary())),
    })
  end

  def new(code, msg, meta \\ %{}) do
    conform!(%__MODULE__{code: code, msg: msg, meta: meta}, s())
  end

  @impl true
  def message(%__MODULE__{msg: msg}), do: msg

  defimpl Jason.Encoder do
    def encode(struct, opts) do
      map = if struct.meta == %{} do
        Map.take(struct, [:code, :msg])
      else
        Map.take(struct, [:code, :msg, :meta])
      end

      Jason.Encode.map(map, opts)
    end
  end
end
