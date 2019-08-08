defmodule TelemetryMetricsInfluxDB do
  alias TelemetryMetricsInfluxDB.{EventHandlerHTTP, EventHandlerUDP, UDP}
  require Logger

  @default_port 8086
  @type option ::
          {:port, :inet.port_number()}
          | {:host, String.t()}
          | {:protocol, atom()}
          | {:db, String.t()}
          | {:username, String.t()}
          | {:password, String.t()}
          | {:events, [event]}
          | {:tags, tags}

  @type options :: [option]
  @type event :: %{required(:name) => :telemetry.event_name()}
  @type tags :: map()

  @spec start_link(options) :: GenServer.on_start()
  def start_link(options) do
    config =
      options
      |> Enum.into(%{})
      |> Map.put_new(:protocol, :http)
      |> Map.put_new(:host, "localhost")
      |> Map.put_new(:port, @default_port)
      |> Map.put_new(:tags, %{})
      |> validate_required!([:db, :events])
      |> validate_event_fields!()
      |> validate_protocol!()

    GenServer.start_link(__MODULE__, config)
  end

  @doc false
  @spec get_udp(pid()) :: UDP.t()
  def get_udp(reporter) do
    GenServer.call(reporter, :get_udp)
  end

  @doc false
  @spec udp_error(pid(), UDP.t(), reason :: term) :: :ok
  def udp_error(reporter, udp, reason) do
    GenServer.cast(reporter, {:udp_error, udp, reason})
  end

  def init(config) do
    Process.flag(:trap_exit, true)
    init_protocol(config)
  end

  defp init_protocol(%{protocol: :udp} = config), do: init_udp(config)
  defp init_protocol(%{protocol: :http} = config), do: init_http(config)

  defp init_protocol(_) do
    {:stop, :bad_protocol}
  end

  defp init_http(config) do
    config = %{config | port: :erlang.integer_to_binary(config.port)}
    handler_ids = EventHandlerHTTP.attach(config.events, self(), config)

    {:ok, Map.merge(config, %{handler_ids: handler_ids})}
  end

  defp init_udp(config) do
    case UDP.open(:erlang.binary_to_list(config.host), config.port) do
      {:ok, udp} ->
        handler_ids = EventHandlerUDP.attach(config.events, self(), config)
        {:ok, Map.merge(config, %{udp: udp, handler_ids: handler_ids})}

      {:error, reason} ->
        {:error, {:udp_open_failed, reason}}
    end
  end

  defp handler_module(:udp), do: EventHandlerUDP
  defp handler_module(:http), do: EventHandlerHTTP

  @impl true
  def handle_info({:EXIT, _pid, reason}, state) do
    {:stop, reason, state}
  end

  @impl true
  def handle_call(:get_udp, _from, state) do
    {:reply, state.udp, state}
  end

  @impl true
  def handle_cast({:udp_error, udp, reason}, %{udp: udp} = state) do
    Logger.error("Failed to publish metrics over UDP: #{inspect(reason)}")

    case UDP.open(state.host, state.port) do
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

  def stop(reporter) do
    GenServer.stop(reporter)
  end

  @impl true
  def terminate(_reason, state) do
    handler_module(state.protocol).detach(state.handler_ids)

    :ok
  end

  defp validate_protocol!(%{protocol: :udp} = opts), do: opts
  defp validate_protocol!(%{protocol: :http} = opts), do: opts

  defp validate_protocol!(_) do
    raise(ArgumentError, "protocol has to be :udp or :http")
  end

  defp validate_event_fields!(%{events: []}) do
    raise(ArgumentError, "you need to attach to at least one event")
  end

  defp validate_event_fields!(%{events: events} = opts) when is_list(events) do
    Enum.map(events, &validate_required!(&1, :name))
    opts
  end

  defp validate_event_fields!(%{events: _}) do
    raise(ArgumentError, ":events needs to be list of events")
  end

  defp validate_required!(opts, fields) when is_list(fields) do
    Enum.map(fields, &validate_required!(opts, &1))
    opts
  end

  defp validate_required!(opts, field) do
    case Map.has_key?(opts, field) do
      true ->
        opts

      false ->
        raise(ArgumentError, "#{inspect(field)} field needs to be specified")
    end
  end
end
