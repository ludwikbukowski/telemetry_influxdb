defmodule TelemetryMetricsInfluxDB.HTTP.Connector do
  alias TelemetryMetricsInfluxDB.HTTP.EventHandler
  require Logger

  @default_workers_num 3

  def start_link(config) do
    Supervisor.start_link(__MODULE__, config, name: __MODULE__)
  end

  def init(config) do
    config = %{config | port: :erlang.integer_to_binary(config.port)}

    worker_pool_spec = %{
      id: WorkerPool,
      start: {:wpool, :start_pool, [:http_pool, [{:workers, 3}]]}
    }

    insert_pool(config.prefix, :http_pool)

    Supervisor.init([worker_pool_spec], strategy: :one_for_one)
  end

  def get_pool(prefix) do
    case :ets.lookup(table_name(prefix), "pool") do
      [{"pool", sock}] -> sock
      _ -> :no_pool
    end
  end

  defp insert_pool(prefix, socket) do
    :ets.insert(table_name(prefix), {"pool", socket})
  end

  defp table_name(prefix) do
    :erlang.binary_to_atom(prefix <> "_influx_reporter", :utf8)
  end
end
