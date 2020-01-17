defmodule Mix.Tasks.Compile.Twirp do
  use Mix.Task.Compiler

  @impl true
  def run(_) do
    protos = Path.wildcard("priv/rpc/**/*.proto")
    prefix = Mix.Project.config()[:app] |> Atom.to_string() |> Macro.camelize()
    service_root = "lib/rpc"
    File.mkdir(service_root)
    generate_pb_modules(protos)

    template_root = Path.expand("../../templates", __DIR__)

    for proto <- protos do
      name = proto |> Path.basename() |> Path.rootname()
      service_root = "lib/rpc"
      File.mkdir(service_root)
      source = String.to_charlist(Path.join(service_root, "#{name}_pb.erl"))
      {:ok, pb_mod, binary} = :compile.file(source, [:binary, :report])
      :code.purge(pb_mod)
      {:module, pb_mod} = :code.load_binary(pb_mod, source, binary)

      for service_name <- pb_mod.get_service_names() do
        template_root = Path.expand("../../templates", __DIR__)

        for {{:msg, msg}, keys} <- pb_mod.get_msg_defs() do
          keys = Enum.map(keys, & &1.name)
          bindings = [prefix: prefix, pb_mod: pb_mod, msg: msg, keys: keys]
          code = EEx.eval_file(Path.join(template_root, "msg.ex.exs"), bindings)
          msg_file_name = "#{String.downcase(Atom.to_string(msg))}.ex"
          write!(Path.join(service_root, msg_file_name), code)
        end

        package = pb_mod.get_package_name()
        methods =
          pb_mod.get_rpc_names(service_name)
          |> Enum.map(& pb_mod.fetch_rpc_def(service_name, &1))
          |> Enum.map(fn method ->
            handler_fn = method.name
            Map.put(method, :handler_fn, handler_fn)
          end)
          |> Enum.map(fn m ->
            input = Module.concat([service_name, RPC, m.input])
            output = Module.concat([service_name, RPC, m.output])
            handler_fn = handler_name(m.name)
            ":#{m.name}, #{strip_elixir(input)}, #{strip_elixir(output)}, :#{handler_fn}"
          end)

        bindings = [
          prefix: prefix,
          package: package,
          service_name: service_name,
          methods: methods
        ]

        code = EEx.eval_file(Path.join(template_root, "client.ex.exs"), bindings)
        write!(Path.join(service_root, "#{name}_client.ex"), code)

        code = EEx.eval_file(Path.join(template_root, "service.ex.exs"), bindings)
        write!(Path.join(service_root, "#{name}_service.ex"), code)
      end
    end

    :ok
  end

  defp strip_elixir(mod) do
    mod
    |> Atom.to_string()
    |> String.trim_leading("Elixir.")
  end

  defp handler_name(name) do
    Macro.underscore(Module.concat([name]))
  end

  defp generate_pb_modules(protos) do
    protoc_erl_path = Path.join([Mix.Project.deps_paths()[:gpb], "bin", "protoc-erl"])

    args =
      [
        protoc_erl_path,
        "-o",
        "lib/rpc",
        "-modsuffix",
        "_pb",
        "-json",
        "-maps",
        "-strbin",
      ] ++ protos

    System.cmd("escript", args, into: IO.stream(:stdio, :line))
  end

  defp write!(path, code) do
    File.write!(path, Code.format_string!(code))
  end

  @impl true
  def clean() do
    # files =
    #   ~w(lib/rpc/client.ex lib/rpc/server.ex) ++
    #     Path.wildcard("lib/rpc/**/*_pb.erl") ++
    #     Path.wildcard("lib/rpc/**/*_{client,server}.ex")

    # Enum.each(files, &File.rm_rf!/1)
  end
end
