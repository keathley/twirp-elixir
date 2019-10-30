defmodule Twirp.Client.HTTP do
  alias Twirp.Encoder

  def make_rpc(client, base_path, method, output, req) do
    path = "#{base_path}/#{method}"

    # TODO - work out encoding that we should be using by looking
    # at the content type header
    encoded_payload = output.encode(req)
    case Tesla.post(client, path, encoded_payload) do
      {:ok, %{status: 200}=env} ->
        IO.inspect(env, label: "Env")
        {_, content_type} = Enum.find(env.headers, fn {t, _v} ->
          t == "content-type"
        end)

        Encoder.decode(env.body, output, content_type)
    end
  end
end
