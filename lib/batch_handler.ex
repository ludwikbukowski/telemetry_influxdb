defmodule TelemetryInfluxDB.BatchHandler do
  def handle_batch(batch) do
    config = batch_config(batch)
    publisher = config.publisher

    batch
    |> batch_events()
    |> Enum.join("\n")
    |> publisher.publish(config)
  end

  def batch_config([{_event, config} | _rest]), do: config
  def batch_events(batch), do: Enum.map(batch, fn {event, _} -> event end)
end
