defmodule TelemetryMetricsInfluxDB.UDP.EventHandler do
  require Logger

  @default_workers_num 3

  alias TelemetryMetricsInfluxDB.Formatter
  import HTTPoison.Response
  alias TelemetryMetricsInfluxDB, as: InfluxDB
  alias TelemetryMetricsInfluxDB.UDP.Socket
  alias TelemetryMetricsInfluxDB.UDP.Connector
  require Logger

  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  def init(config) do
    Process.flag(:trap_exit, true)
    config = %{config | port: :erlang.integer_to_binary(config.port)}
    config = Map.put(config, :reporter, self())
    handler_ids = attach_events(config.events, config)

    {:ok, %{handler_ids: handler_ids}}
  end

  def attach_events(event_specs, config) do
    handler_ids =
      Enum.map(event_specs, fn e ->
        handler_id = handler_id(e.name)
        :ok = :telemetry.attach(handler_id, e.name, &__MODULE__.handle_event/4, config)
        handler_id
      end)
  end

  @spec handle_event(
          InfluxDB.event_name(),
          InfluxDB.event_measurements(),
          InfluxDB.event_metadata(),
          InfluxDB.handler_config()
        ) :: :ok
  def handle_event(event, measurements, metadata, config) do
    udp = Connector.get_udp(config.prefix)
    event_tags = Map.get(metadata, :tags, %{})
    packet = Formatter.format(event, measurements, Map.merge(config.tags, event_tags)) <> "\n"

    case Socket.send(udp, packet) do
      :ok ->
        :ok

      {:error, reason} ->
        Connector.udp_error(config.reporter, udp, reason)
    end
  end

  def handle_info({:EXIT, _pid, reason}, state) do
    {:stop, reason, state}
  end

  def terminate(_reason, state) do
    for handler_id <- state.handler_ids do
      :telemetry.detach(handler_id)
    end

    :ok
  end

  @spec handler_id(InfluxDB.event_name()) :: InfluxDB.handler_id()
  defp handler_id(event_name) do
    {__MODULE__, event_name}
  end
end
