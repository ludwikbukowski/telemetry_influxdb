defmodule TelemetryInfluxDB.UDP.EventHandler do
  require Logger


  alias TelemetryInfluxDB.Formatter
  import HTTPoison.Response
  alias TelemetryInfluxDB, as: InfluxDB
  alias TelemetryInfluxDB.UDP.Socket
  alias TelemetryInfluxDB.UDP.Connector
  require Logger

  @spec start_link(InfluxDB.config()) :: GenServer.on_start()
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

  @spec attach_events(InfluxDB.event_spec(), InfluxDB.config()) :: list(InfluxDB.handler_id())
  def attach_events(event_specs, config) do
    Enum.map(event_specs, fn e ->
      handler_id = handler_id(e.name, config.reporter_name)
      :ok = :telemetry.attach(handler_id, e.name, &__MODULE__.handle_event/4, config)
      handler_id
    end)
  end

  @spec handle_event(
          InfluxDB.event_name(),
          InfluxDB.event_measurements(),
          InfluxDB.event_metadata(),
          InfluxDB.config()
        ) :: :ok
  def handle_event(event, measurements, metadata, config) do
    udp = Connector.get_udp(config.reporter_name)
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

  @spec handler_id(InfluxDB.event_name(), binary()) :: InfluxDB.handler_id()
  defp handler_id(event_name, prefix) do
    {__MODULE__, event_name, prefix}
  end
end
