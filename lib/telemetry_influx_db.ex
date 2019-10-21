defmodule TelemetryInfluxDB do
  alias TelemetryInfluxDB.HTTP
  alias TelemetryInfluxDB.UDP
  require Logger

  @moduledoc """
  `Telemetry` reporter for InfluxDB compatible events.

  To use it, start the reporter with the `start_link/1` function, providing it a list of
  `Telemetry` event names:
  ```elixir
     TelemetryMetricsInfluxDB.start_link(
       events: [
         %{name: [:memory, :usage]},
         %{name: [:http, :request]},
       ]
     )
  ```
  > Note that in the real project the reporter should be started under a supervisor, e.g. the main
  > supervisor of your application.

  By default, the reporter sends events through UDP to localhost:8089.

  Note that the reporter doesn't aggregate events in-process - it sends updates to InfluxDB
  whenever a relevant Telemetry event is emitted.

  #### Configuration

  Possible options for the reporter:
     * `:reporter_name` - unique name for the reporter. The purpose is to distinguish between different reporters running in the system.
     One can run separate independent InfluxDB reporters, with different configurations and goals.
     * `:protocol` - :udp or :http. Which protocol to use for connecting to InfluxDB. Default option is :udp.
     * `:host` - host, where InfluxDB is running.
     * `:port` - port, where InfluxDB is running.
     * `:db` - name of InfluxDB's  instance.
     * `:username` - username of InfluxDB's user that has writes privileges.
     * `:password` - password for the user.
     * `:events` - list of `Telemetry` events' names that we want to send to InfluxDB.
     Each event should be specified by the map with the field `name`, e.g. %{name: [:sample, :event, :name]}.
     Event names should be compatible with `Telemetry` events' format.
     * `:tags` - list of global tags, that will be attached to each reported event. The format is a map,
     where the key and the value are tag's name and value, respectively.
     Both the tag's name and the value could be atoms or binaries.

  #### Notes

  For the HTTP protocol, [worker_pool](https://github.com/inaka/worker_pool) is used for sending requests asynchronously.
  Therefore the HTTP requests are sent in the context of the separate workers' pool, which does not block the client's application
  (it is not sent in the critical path of the client's process).
  The events are sent straightaway without any batching techniques.
  On the other hand, UDP packets are sent in the context of the processes that execute the events.
  However, the lightweight nature of UDP should not cause any bottlenecks in such a solution.

  Once the reporter is started, it is attached to specified `Telemetry` events.
  The events are detached when the reporter is shutdown.

  """

  @default_port 8089

  @type option ::
          {:port, :inet.port_number()}
          | {:host, String.t()}
          | {:protocol, atom()}
          | {:reporter_name, binary()}
          | {:db, String.t()}
          | {:username, String.t()}
          | {:password, String.t()}
          | {:events, [event]}
          | {:tags, tags}

  @type options :: [option]
  @type event :: %{required(:name) => :telemetry.event_name()}
  @type tags :: map()
  @type event_spec() :: map()
  @type event_name() :: [atom()]
  @type event_measurements :: map()
  @type event_metadata :: map()
  @type config :: map()
  @type handler_id() :: term()

  @spec start_link(options) :: GenServer.on_start()
  def start_link(options) do
    config =
      options
      |> Enum.into(%{})
      |> Map.put_new(:reporter_name, "default")
      |> Map.put_new(:protocol, :udp)
      |> Map.put_new(:host, "localhost")
      |> Map.put_new(:port, @default_port)
      |> Map.put_new(:tags, %{})
      |> validate_required!([:db, :events])
      |> validate_event_fields!()
      |> validate_protocol!()

    create_ets(config.reporter_name)
    specs = child_specs(config.protocol, config)
    Supervisor.start_link(specs, strategy: :one_for_all)
  end

  defp create_ets(prefix) do
    try do
      :ets.new(table_name(prefix), [:set, :public, :named_table])
    rescue
      _ ->
        :ok
    end
  end

  defp table_name(prefix) do
    :erlang.binary_to_atom(prefix <> "_influx_reporter", :utf8)
  end

  def stop(pid) do
    Supervisor.stop(pid)
  end

  defp child_specs(:http, config), do: http_child_specs(config)
  defp child_specs(:udp, config), do: udp_child_specs(config)

  defp http_child_specs(config) do
    [
      HTTP.Pool.child_spec(config),
      %{id: HTTP.Handler, start: {HTTP.EventHandler, :start_link, [config]}}
    ]
  end

  defp udp_child_specs(config) do
    [
      %{id: UDP.Connector, start: {UDP.Connector, :start_link, [config]}},
      %{id: UDP.Handler, start: {UDP.EventHandler, :start_link, [config]}}
    ]
  end

  defp validate_protocol!(%{protocol: :udp} = opts), do: opts
  defp validate_protocol!(%{protocol: :http} = opts), do: opts

  defp validate_protocol!(_) do
    raise(ArgumentError, "protocol has to be :udp or :http")
  end

  defp validate_event_fields!(%{events: []}) do
    raise(ArgumentError, "you need to attach to at least one event")
  end

  defp validate_event_fields!(%{events: events} = opts) when is_list(events) do
    Enum.map(events, &validate_required!(&1, :name))
    opts
  end

  defp validate_event_fields!(%{events: _}) do
    raise(ArgumentError, ":events needs to be list of events")
  end

  defp validate_required!(opts, fields) when is_list(fields) do
    Enum.map(fields, &validate_required!(opts, &1))
    opts
  end

  defp validate_required!(opts, field) do
    case Map.has_key?(opts, field) do
      true ->
        opts

      false ->
        raise(ArgumentError, "#{inspect(field)} field needs to be specified")
    end
  end
end
