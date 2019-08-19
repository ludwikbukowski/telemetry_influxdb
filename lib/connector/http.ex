defmodule TelemetryMetricsInfluxDB.Connector.HTTP do
  alias TelemetryMetricsInfluxDB.EventHandler
  require Logger

  def init(config) do
    Process.flag(:trap_exit, true)
    config = %{config | port: :erlang.integer_to_binary(config.port)}
    handler_ids = EventHandler.HTTP.attach(config.events, self(), config)

    #    child = [{:wpool, :start_pool, [:http_pool, workers: @default_workers_num]}]
    #    Supervisor.init(child, strategy: :one_for_one)

    {:ok, Map.merge(config, %{handler_ids: handler_ids})}
  end

  def handle_info({:EXIT, _pid, reason}, state) do
    {:stop, reason, state}
  end

  def terminate(_reason, state) do
    EventHandler.HTTP.detach(state.handler_ids)

    :ok
  end
end
