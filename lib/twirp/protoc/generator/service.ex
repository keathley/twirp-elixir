defmodule Twirp.Protoc.Generator.Service do
  @moduledoc false
  # Build a service file

  alias Protobuf.Protoc.Generator.Util

  def generate_list(ctx, descs) do
    Enum.map(descs, fn desc -> generate(ctx, desc) end)
  end

  def generate(ctx, desc) do
    # service can't be nested
    mod_name = Util.mod_name(ctx, [Util.trans_name(desc.name)])
    methods = Enum.map(desc.method, fn m -> generate_service_method(ctx, m) end)

    Twirp.Protoc.Template.service(mod_name, "#{ctx.package}", desc.name, methods)
  end

  defp generate_service_method(ctx, m) do
    input = Util.type_from_type_name(ctx, m.input_type)
    output = Util.type_from_type_name(ctx, m.output_type)
    handler_fn = Macro.underscore(m.name)
    comments = String.trim(m[:comments] || "")

    %{name: m.name, input: input, output: output, handler_fn: handler_fn, comments: comments}
  end
end
