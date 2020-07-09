defmodule TelemetryInfluxDB.HTTP.EventHandler do
  @moduledoc false
  require Logger
  alias TelemetryInfluxDB.HTTP.Pool

  alias TelemetryInfluxDB.Formatter
  import HTTPoison.Response
  alias TelemetryInfluxDB, as: InfluxDB
  require Logger

  @spec add_internal_config(InfluxDB.config()) :: InfluxDB.config()
  def add_internal_config(config) do
    pool_name = Pool.get_name(config.reporter_name)

    config
    |> Map.put(:pool_name, pool_name)
    |> Map.put(:send_event, &__MODULE__.send_event/2)
  end

  @spec send_event(String.t(), InfluxDB.config()) :: :ok
  def send_event(formatted_event, config) do
    url = build_url(config)
    body = formatted_event
    headers = Map.merge(authentication_header(config), binary_data_header())

    :wpool.cast(config.pool_name, {__MODULE__, :send_event, [url, body, headers]})
  end

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

      telemetry_config =
        Map.delete(config, :events)
        |> Map.put(:pool_name, pool_name)
        |> Map.put(:metadata_tag_keys, e[:metadata_tag_keys] || [])

      handler_id = handler_id(e.name, config.reporter_name)
      :ok = :telemetry.attach(handler_id, e.name, &__MODULE__.handle_event/4, telemetry_config)
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
    url = build_url(config)

    event_tags = Map.get(metadata, :tags, %{})
    event_metadatas = Map.take(metadata, config.metadata_tag_keys)

    tags =
      Map.merge(config.tags, event_tags)
      |> Map.merge(event_metadatas)

    body = Formatter.format(event, measurements, tags)

    headers = Map.merge(authentication_header(config), binary_data_header())

    :wpool.cast(config.pool_name, {__MODULE__, :send_event, [url, body, headers]})
  end

  @spec send_event(binary, any, any) :: :ok
  def send_event(url, body, headers) do
    process_response(HTTPoison.post(url, body, headers))
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

  defp build_url(%{version: :v1, host: host, port: port, db: db}) do
    query = URI.encode_query(%{db: db})
    host <> ":" <> port <> "/write?" <> query
  end

  defp build_url(%{version: :v2, host: host, port: port, org: org, bucket: bucket}) do
    query = URI.encode_query(%{bucket: bucket, org: org})
    host <> ":" <> port <> "/api/v2/write?" <> query
  end

  defp authentication_header(%{version: :v1, username: username, password: password}) do
    %{"Authorization" => "Basic #{Base.encode64(username <> ":" <> password)}"}
  end

  defp authentication_header(%{version: :v2, token: token}) do
    %{"Authorization" => "Token #{token}"}
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
