defmodule Twirp.Client.HTTP do
  alias Twirp.Encoder

  alias Twirp.Error

  def make_rpc(client, base_path, method, input, output, req) do
    path = "#{base_path}/#{method}"

    # TODO - work out encoding that we should be using by looking
    # at the content type header
    encoded_payload = input.encode(req)
    case Tesla.post(client, path, encoded_payload) do
      {:ok, %{status: 200}=env} ->
        # IO.inspect(env, label: "Env")
        {_, content_type} = Enum.find(env.headers, fn {t, _v} ->
          t == "content-type"
        end)

        Encoder.decode(env.body, output, content_type)

      # If we're not getting a 200 then we know its an error. Errors are always
      # json so we don't need to check the headers.
      {:ok, %{status: status, body: body}=env} ->
        case Encoder.decode_json(body) do
          {:ok, error} ->
            error = Error.new(error)
            {:error, error}

          {:error, _} ->
            # TODO - Handle invalid json being returned
        end

    end
  end
end
