defmodule TelemetryMetricsInfluxDB.HTTP.Pool do
  require Logger

  @default_workers_num 3

  def child_spec(config) do
    config = %{config | port: :erlang.integer_to_binary(config.port)}

    delete_old_pool(config.prefix)
    insert_pool(config.prefix, pool_name(config.prefix))

    %{
      id: pool_name(config.prefix),
      start: {:wpool, :start_pool, [pool_name(config.prefix), [{:workers, @default_workers_num}]]}
    }
  end

  defp pool_name(prefix) do
    :erlang.binary_to_atom(prefix <> "_WorkerPool", :utf8)
  end

  def get_name(prefix) do
    case :ets.lookup(table_name(prefix), "pool") do
      [{"pool", sock}] -> sock
      _ -> :no_pool
    end
  end

  defp insert_pool(prefix, socket) do
    :ets.insert(table_name(prefix), {"pool", socket})
  end

  defp delete_old_pool(prefix) do
    :ets.delete(table_name(prefix), "pool")
  end

  defp table_name(prefix) do
    :erlang.binary_to_atom(prefix <> "_influx_reporter", :utf8)
  end
end
