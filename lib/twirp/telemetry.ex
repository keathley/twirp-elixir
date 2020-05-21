defmodule Twirp.Telemetry do
  @moduledoc """
  Provides telemetry for twirp clients and servers

  Twirp executes the following events:

    * `[:twirp, :rpc, :start]` - Executed before making an rpc call to another service.

    #### Measurements

      * `:system_time` - The system time

    #### Metadata

      * `:client` - The client module issuing the call.
      * `:method` - The RPC method
      * `:service` - The url for the service

    * `[:twirp, :rpc, :stop]` - Executed after a connection is retrieved from the pool.

    #### Measurements

      * `:duration` - Duration to send an rpc to a service and wait for a response.

    #### Metadata

      * `:client` - The client module issuing the call.
      * `:method` - The RPC method
      * `:service` - The url for the service
      * `:error` - Optional key. If the call resulted in an error this key will be present along with the Twirp Error.

    * `[:twirp, :call, :start]` - Executed before the twirp handler is called

    #### Measurements

      * `:system_time` - The system time

    #### Metadata

      There is no metadata for this event.

    * `[:twirp, :call, :stop]` - Executed after twirp handler has been executed.

    #### Measurements

      * `:duration` - Duration to handle the rpc call.

    #### Metadata

      * `:content_type` - The content type being used, either proto or json.
      * `:method` - The name of the method being executed.
      * `:error` - Optional key. If the call resulted in an error this key will be present along with the Twirp Error.

    * `[:twirp, :call, :exception]` - Executed if the twirp handler raises an exception

    #### Measurements

      * `:duration` - Duration to handle the rpc call.

    #### Metadata

      * `:kind` - The kind of error that was raised.
      * `:error` - The exception
      * `:stacktrace` - The stacktrace
  """

  @doc false
  def start(event, meta \\ %{}, extra_measurements \\ %{}) do
    start_time = System.monotonic_time()

    :telemetry.execute(
      [:twirp, event, :start],
      Map.merge(extra_measurements, %{system_time: System.system_time()}),
      meta
    )

    start_time
  end

  @doc false
  def stop(event, start_time, meta \\ %{}, extra_measurements \\ %{}) do
    end_time = System.monotonic_time()
    measurements = Map.merge(extra_measurements, %{duration: end_time - start_time})

    :telemetry.execute(
      [:twirp, event, :stop],
      measurements,
      meta
    )
  end

  @doc false
  def exception(event, start_time, kind, reason, stack, meta \\ %{}, extra_measurements \\ %{}) do
    end_time = System.monotonic_time()
    measurements = Map.merge(extra_measurements, %{duration: end_time - start_time})

    meta =
      meta
      |> Map.put(:kind, kind)
      |> Map.put(:error, reason)
      |> Map.put(:stacktrace, stack)

    :telemetry.execute([:twirp, event, :exception], measurements, meta)
  end

  @doc false
  def event(event, measurements, meta) do
    :telemetry.execute([:twirp, event], measurements, meta)
  end
end
