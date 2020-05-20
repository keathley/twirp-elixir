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

    ctx =
      %Protobuf.Protoc.Context{}
      |> Protobuf.Protoc.CLI.parse_params(request.parameter)
      |> Protobuf.Protoc.CLI.find_types(request.proto_file)

    files =
      request.proto_file
      |> Enum.filter(fn desc -> Enum.member?(request.file_to_generate, desc.name) end)
      |> Enum.map(&convert_to_maps/1)
      |> Enum.map(&add_comments_to_methods/1)
      |> Enum.map(fn desc -> Twirp.Protoc.Generator.generate(ctx, desc) end)

    response = Google.Protobuf.Compiler.CodeGeneratorResponse.new(file: files)
    IO.binwrite(Protobuf.Encoder.encode(response))
  end

  defp add_comments_to_methods(desc) do
    import Access

    # Protobuf elixir has no way to find the actual field numbers. But we need
    # them in order to find the correct service and rpc definition. It just so
    # happens that the "service" field on the descriptor is number 6 and the method descriptor
    # is number 2. So we explicitly check for that and then move on.
    comments =
      desc.source_code_info.location
      |> Enum.reject(fn loc -> loc.leading_comments == nil end)
      |> Enum.filter(fn loc -> match?([6, _, 2, _], loc.path) end)
      |> Enum.map(fn %{path: [6, service, 2, method], leading_comments: comments} -> {service, method, comments} end)

    Enum.reduce(comments, desc, fn {service, method, comment}, desc ->
      desc
      |> put_in([:service, at(service), :method, at(method), :comments], comment)
    end)
  end

  defp convert_to_maps(desc) do
    services = Enum.map(desc.service, fn s ->
      methods = Enum.map(s.method, fn m ->
        Map.from_struct(m)
      end)

      s
      |> Map.put(:method, methods)
      |> Map.from_struct
    end)

    desc
    |> Map.put(:service, services)
    |> Map.from_struct()
  end
end
