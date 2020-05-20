defmodule Twirp.Protoc.Template do
  @moduledoc false
  # Sets up the service template. I'm not even sure all of this ceremony is
  # worth it.

  @svc_tmpl Path.expand("./templates/service.ex.eex", :code.priv_dir(:twirp))

  require EEx

  EEx.function_from_file(:def, :service, @svc_tmpl, [:mod_name, :package, :service_name, :methods])
end
