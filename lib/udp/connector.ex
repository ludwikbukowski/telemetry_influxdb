defmodule TelemetryInfluxDB.UDP.Connector do
  @moduledoc false
  require Logger
  alias TelemetryInfluxDB.UDP.Socket
  alias TelemetryInfluxDB, as: InfluxDB

  @spec start_link(InfluxDB.config()) :: GenServer.on_start()
  def start_link(config) do
    server_name = process_name(config.reporter_name)
    GenServer.start_link(__MODULE__, config, name: server_name)
  end

  def init(config) do
    case Socket.open(:erlang.binary_to_list(config.host), config.port) do
      {:ok, udp} ->
        delete_old_socket_ets(config.reporter_name)
        insert_socket_ets(config.reporter_name, udp)
        {:ok, config}

      {:error, reason} ->
        {:error, {:udp_open_failed, reason}}
    end
  end

  @spec get_udp(binary()) :: Socket.t()
  def get_udp(prefix) do
    case :ets.lookup(table_name(prefix), "socket") do
      [{"socket", sock}] -> sock
      _ -> :no_socket
    end
  end

  @spec udp_error(String.t(), Socket.t(), term()) :: :ok
  def udp_error(reporter_name, udp, reason) do
    server_name = process_name(reporter_name)
    GenServer.cast(server_name, {:udp_error, udp, reason})
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

  defp process_name(prefix) do
    :erlang.binary_to_atom(prefix <> "_udp_connector", :utf8)
  end

  def handle_cast({:udp_error, _, reason}, state) do
    Logger.error("Failed to publish metrics over UDP: #{inspect(reason)}")

    case Socket.open(state.host, state.port) do
      {:ok, udp} ->
        insert_socket_ets(state.reporter_name, udp)
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Failed to reopen UDP socket: #{inspect(reason)}")
        {:stop, {:udp_open_failed, reason}, state}
    end
  end
end
