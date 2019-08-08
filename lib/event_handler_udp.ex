defmodule TelemetryMetricsInfluxDB.EventHandlerUDP do
  alias TelemetryMetricsInfluxDB.Formatter
  import HTTPoison.Response
  alias TelemetryMetricsInfluxDB.UDP
  require Logger

  @type event_spec() :: map()
  @type event_name() :: [atom()]
  @type event_measurements :: map()
  @type event_metadata :: map()
  @type handler_config :: term()
  @type handler_id() :: term()

  @spec attach(event_spec, pid(), handler_config()) :: [handler_id()]
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

  @spec handle_event(event_name(), event_measurements(), event_metadata(), handler_config()) ::
          :ok
  def handle_event(event, measurements, metadata, config) do
    udp = TelemetryMetricsInfluxDB.get_udp(config.reporter)
    event_tags = Map.get(metadata, :tags, %{})
    packet = Formatter.format(event, measurements, Map.merge(config.tags, event_tags)) <> "\n"

    case UDP.send(udp, packet) do
      :ok ->
        :ok

      {:error, reason} ->
        TelemetryMetricsInfluxDB.udp_error(config.reporter, udp, reason)
    end
  end

  @spec detach([handler_id()]) :: :ok
  def detach(handler_ids) do
    for handler_id <- handler_ids do
      :telemetry.detach(handler_id)
    end

    :ok
  end

  @spec handler_id(event_name(), reporter :: pid) :: handler_id()
  defp handler_id(event_name, reporter) do
    {__MODULE__, reporter, event_name}
  end
end
