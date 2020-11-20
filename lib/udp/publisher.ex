defmodule TelemetryInfluxDB.UDP.Publisher do
  @moduledoc false
  alias TelemetryInfluxDB, as: InfluxDB
  alias TelemetryInfluxDB.UDP.Socket
  alias TelemetryInfluxDB.UDP.Connector

  require Logger

  @behaviour InfluxDB.Publisher

  @impl InfluxDB.Publisher
  def add_config(config) do
    config
  end

  @impl InfluxDB.Publisher
  def publish(payload, config) do
    udp = Connector.get_udp(config.reporter_name)
    packet = payload <> "\n"

    case Socket.send(udp, packet) do
      :ok ->
        :ok

      {:error, reason} ->
        Connector.udp_error(config.reporter_name, udp, reason)
    end
  end
end
