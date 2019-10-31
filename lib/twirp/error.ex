defmodule Twirp.Error do
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
    resource_exhausted:   403, # Forbidden
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

  @derive Jason.Encoder
  defstruct ~w|code msg meta|a

  for {code, status} <- @error_code_to_http_status do
    def unquote(code)(msg, meta \\ []) do
      new(unquote(code), msg, meta)
    end
  end

  def valid_code?(code) do
    Map.key?(@error_code_to_http_status, code)
  end

  def code_to_status(code) when code in @error_codes do
    @error_code_to_http_status[code]
  end

  def s do
    schema(%__MODULE__{
      code: spec(is_atom() and (& &1 in @error_codes)),
      msg: spec(is_binary()),
      meta: map_of(spec(is_atom()), spec(is_binary())),
    })
  end

  def new(code, msg, meta \\ []) do
    conform!(%__MODULE__{code: code, msg: msg, meta: Enum.into(meta, %{})}, s())
  end
  def new(map) when is_map(map) do
    # Converting the code to an existing atom is safe to do here because
    # we've definitely defined the correct atoms. better to just blow up.
    code = String.to_existing_atom(map["code"])
    msg = map["msg"]
    meta = map["meta"]
    new(code, msg, meta)
  end
end

