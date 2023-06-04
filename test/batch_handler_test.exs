defmodule TelemetryInfluxDB.BatchHandlerTest do
  use ExUnit.Case, async: true
  alias TelemetryInfluxDB.BatchHandler

  test "handles formatting multiple events" do
    defmodule MockPublish do
      @behaviour TelemetryInfluxDB.Publisher

      @impl TelemetryInfluxDB.Publisher
      def publish(events, config) do
        send(self(), {:published, events, config})
      end

      @impl TelemetryInfluxDB.Publisher
      def add_config(_), do: :noop
    end

    config = %{
      token: "testing123",
      publisher: MockPublish
    }

    batch = [
      {"event1", config},
      {"event2", config},
      {"event3", config}
    ]

    BatchHandler.handle_batch(batch)

    expected_message = "event1\nevent2\nevent3"
    assert_receive {:published, ^expected_message, ^config}
  end
end
