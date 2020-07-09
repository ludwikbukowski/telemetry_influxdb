defmodule TelemetryInfluxDB.HTTP.Publisher do
  @moduledoc false
  import HTTPoison.Response

  alias TelemetryInfluxDB, as: InfluxDB
  alias TelemetryInfluxDB.HTTP.Pool

  require Logger

  @behaviour InfluxDB.Publisher

  @impl InfluxDB.Publisher
  def add_config(config) do
    pool_name = Pool.get_name(config.reporter_name)

    config
    |> Map.update!(:port, &:erlang.integer_to_binary/1)
    |> Map.put(:pool_name, pool_name)
  end

  @impl InfluxDB.Publisher
  def publish(formatted_event, config) do
    url = build_url(config)
    body = formatted_event
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
end
