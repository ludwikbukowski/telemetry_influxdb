defmodule TelemetryMetricsInfluxDB do
  alias TelemetryMetricsInfluxDB.EventHandler

  @default_port 8086

  def start_link(options) do
    config =
      options
      |> Enum.into(%{})
      |> Map.put_new(:host, "localhost")
      |> Map.put_new(:port, @default_port)
      |> Map.put_new(:tags, %{})
      |> validate_required!([:db, :events])
      |> validate_event_fields!()

    GenServer.start_link(__MODULE__, config)
  end

  def init(config) do
    db_config = %{
      host: config.host,
      port: :erlang.integer_to_binary(config.port),
      db: config.db,
      username: config.username,
      password: config.password,
      tags: config.tags
    }

    handler_ids = EventHandler.attach(config.events, self(), db_config)

    {:ok, Map.merge(config, %{handler_ids: handler_ids})}
  end

  def stop(reporter) do
    GenServer.stop(reporter)
  end

  def terminate(_reason, state) do
    EventHandler.detach(state.handler_ids)

    :ok
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
