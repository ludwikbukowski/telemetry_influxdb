defmodule TelemetryMetricsInfluxDB.UDP.EventHandler do
  @moduledoc false

  alias TelemetryMetricsInfluxDB.Formatter
  import HTTPoison.Response
  alias TelemetryMetricsInfluxDB, as: InfluxDB
  alias TelemetryMetricsInfluxDB.UDP.Socket
  alias TelemetryMetricsInfluxDB.UDP.Connector
  require Logger

  @spec attach(InfluxDB.event_spec(), InfluxDB.pid(), InfluxDB.handler_config()) :: [
          InfluxDB.handler_id()
        ]
  def attach(event_specs, reporter, db_config) do
    Enum.map(event_specs, fn e ->
      handler_id = handler_id(e.name, reporter)

      :ok =
        :telemetry.attach(
          handler_id,
          e.name,
          &__MODULE__.handle_event/4,
          Map.put(db_config, :reporter, reporter)
        )

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
    udp = Connector.get_udp(config.reporter)
    event_tags = Map.get(metadata, :tags, %{})
    packet = Formatter.format(event, measurements, Map.merge(config.tags, event_tags)) <> "\n"

    case Socket.send(udp, packet) do
      :ok ->
        :ok

      {:error, reason} ->
        Connector.udp_error(config.reporter, udp, reason)
    end
  end

  @spec detach([InfluxDB.handler_id()]) :: :ok
  def detach(handler_ids) do
    for handler_id <- handler_ids do
      :telemetry.detach(handler_id)
    end

    :ok
  end

  @spec handler_id(InfluxDB.event_name(), reporter :: pid) :: InfluxDB.handler_id()
  defp handler_id(event_name, reporter) do
    {__MODULE__, reporter, event_name}
  end
end
