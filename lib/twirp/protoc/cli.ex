defmodule Twirp.Protoc.CLI do
  @moduledoc false
  # Almost all of this generation stuff is lifted from the elixr protobuf library.
  # I don't love the way its implemented but it was the fastest path forward for
  # supporting generation of services. I'm going to revisit in the future
  # because I barely understand how this code works.

  def main(_) do
    # https://groups.google.com/forum/#!topic/elixir-lang-talk/T5enez_BBTI
    :io.setopts(:standard_io, encoding: :latin1)
    bin = IO.binread(:all)
    request = Protobuf.Decoder.decode(bin, Google.Protobuf.Compiler.CodeGeneratorRequest)
    # debug
    # raise inspect(request, limit: :infinity)

    ctx =
      %Protobuf.Protoc.Context{}
      |> Protobuf.Protoc.CLI.parse_params(request.parameter)
      |> Protobuf.Protoc.CLI.find_types(request.proto_file)

    files =
      request.proto_file
      |> Enum.filter(fn desc -> Enum.member?(request.file_to_generate, desc.name) end)
      |> Enum.map(fn desc -> Twirp.Protoc.Generator.generate(ctx, desc) end)

    response = Google.Protobuf.Compiler.CodeGeneratorResponse.new(file: files)
    IO.binwrite(Protobuf.Encoder.encode(response))
  end
end
