defmodule TelemetryMetricsInfluxDBRealTest do
  use ExUnit.Case, async: false
  alias TelemetryMetricsInfluxDB.Test.InfluxSimpleClient
  import ExUnit.CaptureLog

  @default_options %{
    db: "myinflux",
    username: "myuser",
    password: "mysecretpassword",
    host: "localhost",
    port: 8089
  }

  test "error log message is displayed for invalid influxdb credentials" do
    log =
      capture_log(fn ->
        event = given_event_spec([:request, :failed])
        start_reporter(%{events: [event], username: "badguy", password: "wrongpass"})
        :telemetry.execute([:request, :failed], %{"reason" => "timeout", "retries" => "3"})
      end)

    assert log =~ "Failed to push data to InfluxDB. Invalid credentials"
  end

  test "error log message is displayed for invalid influxdb database" do
    log =
      capture_log(fn ->
        event = given_event_spec([:users, :count])
        start_reporter(%{events: [event], db: "yy_postgres"})
        :telemetry.execute([:users, :count], %{"value" => "30"})
      end)

    assert log =~ "Failed to push data to InfluxDB. Invalid credentials"
  end

  test "event is reported when specified by its name" do
    ## given
    event = given_event_spec([:requests, :failed])
    start_reporter(%{events: [event]})

    ## when
    :telemetry.execute([:requests, :failed], %{"reason" => "timeout", "retries" => 3})

    ## then
    assert_reported("requests.failed", %{"reason" => "timeout", "retries" => 3})
  end

  test "event is reported with correct data types" do
    ## given
    event = given_event_spec([:calls, :failed])
    start_reporter(%{events: [event]})

    ## when
    :telemetry.execute([:calls, :failed], %{
      "int" => 4,
      "string_int" => "3",
      "float" => 0.34,
      "string" => "random",
      "boolean" => true
    })

    ## then
    assert_reported("calls.failed", %{
      "int" => 4,
      "string_int" => "3",
      "float" => 0.34,
      "string" => "random",
      "boolean" => true
    })
  end

  test "only specified events are reported" do
    ## given
    event1 = given_event_spec([:event, :one])
    event2 = given_event_spec([:event, :two])
    event3 = given_event_spec([:event, :three])
    start_reporter(%{events: [event1, event2, event3]})

    ## when
    :telemetry.execute([:event, :one], %{"value" => 1})
    assert_reported("event.one", %{"value" => 1})

    :telemetry.execute([:event, :two], %{"value" => 2})
    assert_reported("event.two", %{"value" => 2})

    :telemetry.execute([:event, :other], %{"value" => "?"})

    ## then
    refute_reported("event.other")
  end

  test "events are reported with global pre-defined tags" do
    ## given
    event = given_event_spec([:memory, :leak])
    start_reporter(%{events: [event], tags: %{region: :eu_central, time_zone: :cest}})

    ## when
    :telemetry.execute([:memory, :leak], %{"memory_leaked" => 100})

    ## then
    assert_reported("memory.leak", %{"memory_leaked" => 100}, %{
      "region" => "\"eu_central\"",
      "time_zone" => "\"cest\""
    })
  end

  test "events are reported with event-specific tags" do
    ## given
    event = given_event_spec([:system, :crash])
    start_reporter(%{events: [event], tags: %{}})

    ## when
    :telemetry.execute([:system, :crash], %{"node_id" => "a3"}, %{tags: %{priority: :high}})

    ## then
    assert_reported("system.crash", %{"node_id" => "a3"}, %{
      "priority" => "\"high\""
    })
  end

  test "events are detached after stoping reporter" do
    ## given
    event_old = given_event_spec([:old, :event])
    event_new = given_event_spec([:new, :event])
    pid = start_reporter(%{events: [event_old, event_new]})
    :telemetry.execute([:old, :event], %{"value" => 1})

    ## when
    TelemetryMetricsInfluxDB.stop(pid)
    :telemetry.execute([:new, :event], %{"value" => 2})

    ## then
    assert_reported("old.event", %{"value" => 1})
  end

  defp given_event_spec(name) do
    %{name: name}
  end

  defp refute_reported(name, config \\ @default_options) do
    q = "SELECT * FROM \"" <> name <> "\""
    res = InfluxSimpleClient.query(config, q)
    assert %{"results" => [%{"statement_id" => 0}]} == res
  end

  defp assert_reported(name, values, tags \\ %{}, config \\ @default_options) do
    q = "SELECT * FROM \"" <> name <> "\""
    res = InfluxSimpleClient.query(config, q)

    [inner_map] = res["results"]
    [record] = inner_map["series"]

    assert record["name"] == name
    assert record["columns"] == ["time"] ++ Map.keys(values) ++ Map.keys(tags)
    map_vals = Map.values(values)
    map_tag_vals = Map.values(tags)
    all_vals = map_vals ++ map_tag_vals

    assert [[_ | tag_and_fields]] = record["values"]
    assert tag_and_fields == all_vals
  end

  defp start_reporter(options) do
    config = Map.merge(@default_options, options)
    {:ok, pid} = TelemetryMetricsInfluxDB.start_link(config)
    pid
  end
end
