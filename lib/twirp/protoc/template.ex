defmodule Twirp.Protoc.Template do
  @svc_tmpl Path.expand("./templates/service.ex.eex", :code.priv_dir(:twirp))

  require EEx

  EEx.function_from_file(:def, :service, @svc_tmpl, [:mod_name, :package, :service_name, :methods],
    trim: true
  )
end
