defmodule TelemetryMetricsInfluxDB.Connector.UDP do
  require Logger
  alias TelemetryMetricsInfluxDB.{EventHandler, UDPSocket}

  def init(config) do
    Process.flag(:trap_exit, true)

    case UDPSocket.open(:erlang.binary_to_list(config.host), config.port) do
      {:ok, udp} ->
        handler_ids = EventHandler.UDP.attach(config.events, self(), config)
        {:ok, Map.merge(config, %{udp: udp, handler_ids: handler_ids})}

      {:error, reason} ->
        {:error, {:udp_open_failed, reason}}
    end
  end

  @doc false
  @spec get_udp(pid()) :: UDPSocket.t()
  def get_udp(reporter) do
    GenServer.call(reporter, :get_udp)
  end

  @doc false
  @spec udp_error(pid(), UDPSocket.t(), reason :: term) :: :ok
  def udp_error(reporter, udp, reason) do
    GenServer.cast(reporter, {:udp_error, udp, reason})
  end

  def handle_info({:EXIT, _pid, reason}, state) do
    {:stop, reason, state}
  end

  def handle_call(:get_udp, _from, state) do
    {:reply, state.udp, state}
  end

  def handle_cast({:udp_error, udp, reason}, %{udp: udp} = state) do
    Logger.error("Failed to publish metrics over UDP: #{inspect(reason)}")

    case UDPSocket.open(state.host, state.port) do
      {:ok, udp} ->
        {:noreply, %{state | udp: udp}}

      {:error, reason} ->
        Logger.error("Failed to reopen UDP socket: #{inspect(reason)}")
        {:stop, {:udp_open_failed, reason}, state}
    end
  end

  def handle_cast({:udp_error, _, _}, state) do
    {:noreply, state}
  end

  def terminate(_reason, state) do
    EventHandler.UDP.detach(state.handler_ids)

    :ok
  end
end
