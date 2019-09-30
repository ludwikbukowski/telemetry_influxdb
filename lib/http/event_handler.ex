defmodule TelemetryMetricsInfluxDB.HTTP.EventHandler do
  require Logger
  alias TelemetryMetricsInfluxDB.HTTP.Pool

  alias TelemetryMetricsInfluxDB.Formatter
  import HTTPoison.Response
  alias TelemetryMetricsInfluxDB, as: InfluxDB
  require Logger

  @spec start_link(InfluxDB.config()) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  def init(config) do
    config = %{config | port: :erlang.integer_to_binary(config.port)}
    Process.flag(:trap_exit, true)
    handler_ids = attach_events(config.events, config)

    {:ok, %{handler_ids: handler_ids}}
  end

  @spec attach_events(InfluxDB.event_spec(), InfluxDB.config()) :: list(InfluxDB.handler_id())
  def attach_events(event_specs, config) do
    Enum.map(event_specs, fn e ->
      pool_name = Pool.get_name(config.reporter_name)
      config = Map.put(config, :pool_name, pool_name)

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
    query = config.host <> ":" <> config.port <> "/write?db=" <> config.db
    event_tags = Map.get(metadata, :tags, %{})
    body = Formatter.format(event, measurements, Map.merge(config.tags, event_tags))

    headers =
      Map.merge(authentication_header(config.username, config.password), binary_data_header())

    :wpool.cast(config.pool_name, {__MODULE__, :send_event, [query, body, headers]})
  end

  def send_event(query, body, headers) do
    process_response(HTTPoison.post(query, body, headers))
  end

  def handle_info({:EXIT, _pid, reason}, state) do
    {:stop, reason, state}
  end

  defp process_response({:ok, %HTTPoison.Response{status_code: 204}}), do: :ok

  defp process_response({:ok, %HTTPoison.Response{status_code: 404}}) do
    Logger.error("Failed to push data to InfluxDB. Invalid credentials")
    :ok
  end

  defp process_response({:ok, %{status_code: 401}}) do
    Logger.error("Failed to push data to InfluxDB. Invalid credentials")
    :ok
  end

  defp process_response(res) do
    Logger.error("Failed to send event to InfluxDB. Response: #{inspect(res)}")
    :ok
  end

  defp authentication_header(username, password) do
    %{"Authorization" => "Basic #{Base.encode64(username <> ":" <> password)}"}
  end

  defp binary_data_header() do
    %{"Content-Type" => "text/plain"}
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
