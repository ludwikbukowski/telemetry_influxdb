defmodule TelemetryMetricsInfluxDB.UDP.Connector do
  require Logger
  alias TelemetryMetricsInfluxDB.UDP.Socket

  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  def init(config) do
    case Socket.open(:erlang.binary_to_list(config.host), config.port) do
      {:ok, udp} ->
        delete_old_socket_ets(config.prefix)
        insert_socket_ets(config.prefix, udp)
        {:ok, config}

      {:error, reason} ->
        {:error, {:udp_open_failed, reason}}
    end
  end

  def get_udp(prefix) do
    case :ets.lookup(table_name(prefix), "socket") do
      [{"socket", sock}] -> sock
      _ -> :no_socket
    end
  end

  def udp_error(reporter, udp, reason) do
    GenServer.cast(reporter, {:udp_error, udp, reason})
  end

  defp insert_socket_ets(prefix, socket) do
    :ets.insert(table_name(prefix), {"socket", socket})
  end

  defp delete_old_socket_ets(prefix) do
    :ets.delete(table_name(prefix), "socket")
  end

  defp table_name(prefix) do
    :erlang.binary_to_atom(prefix <> "_influx_reporter", :utf8)
  end

  def handle_cast({:udp_error, _, reason}, state) do
    Logger.error("Failed to publish metrics over UDP: #{inspect(reason)}")

    case Socket.open(state.host, state.port) do
      {:ok, udp} ->
        insert_socket_ets(state.prefix, udp)
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Failed to reopen UDP socket: #{inspect(reason)}")
        {:stop, {:udp_open_failed, reason}, state}
    end
  end
end
