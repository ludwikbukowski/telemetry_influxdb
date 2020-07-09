defmodule TelemetryInfluxDB.Publisher do
  alias TelemetryInfluxDB, as: InfluxDB

  @callback add_config(InfluxDB.config()) :: InfluxDB.config()
  @callback publish(String.t(), InfluxDB.config()) :: :ok
end
