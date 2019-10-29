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

  def valid_code?(code) do
    Map.key?(@error_code_to_http_status, code)
  end

  # Code constructors to ensure valid error codes. Example:
  #     Twirp::Error.internal("boom")
  #     Twirp::Error.invalid_argument("foo is mandatory", mymeta: "foobar")
  #     Twirp::Error.permission_denied("Thou shall not pass!", target: "Balrog")
  # ERROR_CODES.each do |code|
  #   define_singleton_method code do |msg, meta=nil|
  #     new(code, msg, meta)
  #   end
  # end

  def s do
    schema(%{
      code: spec(is_binary()),
      msg: spec(is_binary())
    })
  end

  def new(code, msg, meta) do
  end

  def new(code, msg, nil) do
    %{code: code, msg: msg}
  end
end

