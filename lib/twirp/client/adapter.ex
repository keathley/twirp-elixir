defmodule Twirp.Client.Adapter do
  @moduledoc false
end

defmodule Twirp.Client.AdapterError do
  defexception [:message]

  @impl true
  def exception(adapter) do
    name = adapter_name(adapter)
    msg = """
    It looks like you're trying to use #{name} as your Twirp adapter,
    but haven't added #{name} to your dependencies.
    Please add :#{adapter} to your dependencies:
    """

    %__MODULE__{message: msg}
  end

  defp adapter_name(:finch), do: "Finch"
  defp adapter_name(:hackney), do: "Hackney"
end
