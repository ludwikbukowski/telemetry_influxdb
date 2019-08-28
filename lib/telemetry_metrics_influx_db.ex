defmodule TelemetryMetricsInfluxDB do
  alias TelemetryMetricsInfluxDB.HTTP
  alias TelemetryMetricsInfluxDB.UDP
  alias TelemetryMetricsInfluxDB.Ids.Storage
  require Logger

  @moduledoc """

  """
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
  @type event_spec() :: map()
  @type event_name() :: [atom()]
  @type event_measurements :: map()
  @type event_metadata :: map()
  @type handler_config :: term()
  @type handler_id() :: term()

  @spec start_link(options) :: GenServer.on_start()
  def start_link(options) do
    config =
      options
      |> Enum.into(%{})
      |> Map.put_new(:prefix, "default")
      |> Map.put_new(:protocol, :udp)
      |> Map.put_new(:host, "localhost")
      |> Map.put_new(:port, @default_port)
      |> Map.put_new(:tags, %{})
      |> validate_required!([:db, :events])
      |> validate_event_fields!()
      |> validate_protocol!()

    specs = child_specs(config.protocol, config)
    create_ets(config.prefix)
    Supervisor.start_link(specs, strategy: :one_for_all)
  end

  defp create_ets(prefix) do
    try do
      :ets.new(table_name(prefix), [:set, :public, :named_table])
    rescue
      _ ->
        :ok
    end
  end

  defp table_name(prefix) do
    :erlang.binary_to_atom(prefix <> "_influx_reporter", :utf8)
  end

  def stop(pid) do
    Supervisor.stop(pid)
  end

  defp child_specs(:http, config), do: http_child_specs(config)
  defp child_specs(:udp, config), do: udp_child_specs(config)

  defp http_child_specs(config) do
    [
      %{id: Pool, start: {HTTP.Connector, :start_link, [config]}},
      %{id: Registry, start: {HTTP.EventHandler, :start_link, [config]}}
    ]
  end

  defp udp_child_specs(config) do
    [
      %{id: UDP, start: {UDP.Connector, :start_link, [config]}},
      %{id: Registry, start: {UDP.EventHandler, :start_link, [config]}}
    ]
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
