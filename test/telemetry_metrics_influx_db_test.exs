defmodule TelemetryMetricsInfluxDBTest do
  use ExUnit.Case, async: false
  alias TelemetryMetricsInfluxDB.Test.InfluxSimpleClient
  import ExUnit.CaptureLog
  import Eventually

  @default_options %{
    db: "myinflux",
    username: "myuser",
    password: "mysecretpassword",
    host: "localhost",
    port: 8087
  }
  describe "Invalid reporter configuration" do
    test "error log message is displayed for invalid influxdb credentials" do
      log =
        capture_log(fn ->
          # given
          event = given_event_spec([:request, :failed])
          start_reporter(%{events: [event], username: "badguy", password: "wrongpass"})
          # when
          :telemetry.execute([:request, :failed], %{"reason" => "timeout", "retries" => "3"})
        end)

      # then
      assert log =~ "Failed to push data to InfluxDB. Invalid credentials"
    end

    test "error log message is displayed for invalid influxdb database" do
      log =
        capture_log(fn ->
          # given
          event = given_event_spec([:users, :count])
          start_reporter(%{events: [event], db: "yy_postgres"})
          # when
          :telemetry.execute([:users, :count], %{"value" => "30"})
        end)

      # then
      assert log =~ "Failed to push data to InfluxDB. Invalid credentials"
    end
  end

  describe "Events reported" do
    for protocol <- [:http, :udp] do
      @tag protocol: protocol
      test "event is reported when specified by its name for #{protocol} API", %{
        protocol: protocol
      } do
        ## given
        event = given_event_spec([:requests, :failed])
        start_reporter(protocol, %{events: [event]})

        ## when
        :telemetry.execute([:requests, :failed], %{"reason" => "timeout", "retries" => 3})

        ## then
        assert_reported("requests.failed", %{"reason" => "timeout", "retries" => 3})
      end

      @tag protocol: protocol
      test "event is reported with correct data types for #{protocol} API", %{
        protocol: protocol
      } do
        ## given
        event = given_event_spec([:calls, :failed])
        start_reporter(protocol, %{events: [event]})

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

      @tag protocol: protocol
      test "only specified events are reported for #{protocol} API", %{protocol: protocol} do
        ## given
        event1 = given_event_spec([:event, :one])
        event2 = given_event_spec([:event, :two])
        event3 = given_event_spec([:event, :three])
        start_reporter(protocol, %{events: [event1, event2, event3]})

        ## when
        :telemetry.execute([:event, :one], %{"value" => 1})
        assert_reported("event.one", %{"value" => 1})

        :telemetry.execute([:event, :two], %{"value" => 2})
        assert_reported("event.two", %{"value" => 2})

        :telemetry.execute([:event, :other], %{"value" => "?"})

        ## then
        refute_reported("event.other")
      end

      @tag protocol: protocol
      test "events are reported with global pre-defined tags for #{protocol} API", %{
        protocol: protocol
      } do
        ## given
        event = given_event_spec([:memory, :leak])

        start_reporter(protocol, %{
          events: [event],
          tags: %{region: :eu_central, time_zone: :cest}
        })

        ## when
        :telemetry.execute([:memory, :leak], %{"memory_leaked" => 100})

        ## then
        assert_reported("memory.leak", %{"memory_leaked" => 100}, %{
          "region" => "\"eu_central\"",
          "time_zone" => "\"cest\""
        })
      end

      @tag protocol: protocol
      test "events are reported with event-specific tags for #{protocol} API", %{
        protocol: protocol
      } do
        ## given
        event = given_event_spec([:system, :crash])
        start_reporter(protocol, %{events: [event], tags: %{}})

        ## when
        :telemetry.execute([:system, :crash], %{"node_id" => "a3"}, %{tags: %{priority: :high}})

        ## then
        assert_reported("system.crash", %{"node_id" => "a3"}, %{
          "priority" => "\"high\""
        })
      end

      @tag protocol: protocol
      test "events are reported with special characters for #{protocol} API", %{
        protocol: protocol
      } do
        ## given
        event1 = given_event_spec([:event, :special1])
        event2 = given_event_spec([:event, :special2])
        start_reporter(protocol, %{events: [event1, event2], tags: %{}})

        ## when
        :telemetry.execute([:event, :special1], %{"equal_sign" => "a=b"}, %{
          tags: %{priority: "hig\"h"}
        })

        :telemetry.execute([:event, :special2], %{"coma_space" => "a,b c"}, %{tags: %{}})

        ## then
        assert_reported("event.special1", %{"equal_sign" => "a\\\=b"}, %{
          "priority" => "\"hig\\\\\"h\""
        })

        assert_reported("event.special2", %{"coma_space" => "a\\,b\\ c"}, %{})
      end

      @tag protocol: protocol
      test "events are detached after stoping reporter for #{protocol} API", %{
        protocol: protocol
      } do
        ## given
        event_old = given_event_spec([:old, :event])
        event_new = given_event_spec([:new, :event])
        pid = start_reporter(protocol, %{events: [event_old, event_new]})

        :telemetry.execute([:old, :event], %{"value" => 1})
        assert_reported("old.event", %{"value" => 1})

        ## when
        TelemetryMetricsInfluxDB.stop(pid)
        :telemetry.execute([:new, :event], %{"value" => 2})

        ## then
        assert_reported("old.event", %{"value" => 1})
        refute_reported("new.event")
      end

      @tag :capture_log
      @tag protocol: protocol
      test "events are not reported when reporter receives an exit signal for #{protocol} API",
           %{protocol: protocol} do
        ## given
        event_first = given_event_spec([:first, :event])
        event_second = given_event_spec([:second, :event])
        pid = start_reporter(protocol, %{events: [event_first, event_second]})

        Process.unlink(pid)

        # Make sure that event handlers are detached even if non-parent process sends an exit signal.
        spawn(fn -> Process.exit(pid, :some_reason) end)
        eventually(fn -> not Process.alive?(pid) end)

        assert :telemetry.list_handlers([:first, :event]) == []
        assert :telemetry.list_handlers([:second, :event]) == []

        :telemetry.execute([:first, :event], %{})
        :telemetry.execute([:second, :event], %{})

        refute_reported("first.event")
        refute_reported("second.event")
      end
    end
  end

  describe "UDP error handling" do
    test "notifying a UDP error logs an error" do
      event = given_event_spec([:some, :event1])
      reporter = start_reporter(:udp, %{events: [event]})

      udp = TelemetryMetricsInfluxDB.get_udp(reporter)

      assert capture_log(fn ->
               TelemetryMetricsInfluxDB.udp_error(reporter, udp, :closed)
               # Can we do better here? We could use `call` instead of `cast` for reporting socket
               # errors.
               Process.sleep(100)
             end) =~ ~r/\[error\] Failed to publish metrics over UDP: :closed/
    end

    test "notifying a UDP error for the same socket multiple times generates only one log" do
      event = given_event_spec([:some, :event2])
      reporter = start_reporter(:udp, %{events: [event]})
      udp = TelemetryMetricsInfluxDB.get_udp(reporter)

      assert capture_log(fn ->
               TelemetryMetricsInfluxDB.udp_error(reporter, udp, :closed)
               Process.sleep(100)
             end) =~ ~r/\[error\] Failed to publish metrics over UDP: :closed/

      assert capture_log(fn ->
               TelemetryMetricsInfluxDB.udp_error(reporter, udp, :closed)
               Process.sleep(100)
             end) == ""
    end

    @tag :capture_log
    test "notifying a UDP error and fetching a socket returns a new socket" do
      event = given_event_spec([:some, :event3])
      reporter = start_reporter(:udp, %{events: [event]})
      udp = TelemetryMetricsInfluxDB.get_udp(reporter)

      TelemetryMetricsInfluxDB.udp_error(reporter, udp, :closed)
      new_udp = TelemetryMetricsInfluxDB.get_udp(reporter)

      assert new_udp != udp
    end
  end

  test "events are not reported when reporter is shut down by its supervisor" do
    event_first = given_event_spec([:first, :event])
    event_second = given_event_spec([:second, :event])
    child_opts = [Map.to_list(@default_options) ++ [events: [event_first, event_second]]]

    {:ok, supervisor} =
      Supervisor.start_link(
        [
          Supervisor.Spec.worker(TelemetryMetricsInfluxDB, child_opts)
        ],
        strategy: :one_for_one
      )

    Process.unlink(supervisor)

    Supervisor.stop(supervisor, :shutdown)

    assert :telemetry.list_handlers([:first, :event]) == []
    assert :telemetry.list_handlers([:second, :event]) == []

    :telemetry.execute([:first, :event], %{})
    :telemetry.execute([:second, :event], %{})

    refute_reported("first.event")
    refute_reported("second.event")
  end

  defp given_event_spec(name) do
    %{name: name}
  end

  defp refute_reported(name, config \\ @default_options) do
    q = "SELECT * FROM \"" <> name <> "\" LIMIT 1"
    res = InfluxSimpleClient.query(config, q)
    assert %{"results" => [%{"statement_id" => 0}]} == res
  end

  defp assert_reported(name, values, tags \\ %{}, config \\ @default_options) do
    eventually(fn ->
      q = "SELECT * FROM \"" <> name <> "\" LIMIT 1"
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
    end)
  end

  defp start_reporter(:udp, options) do
    start_reporter(Map.merge(options, %{protocol: :udp, port: 8089}))
  end

  defp start_reporter(:http, options), do: start_reporter(options)

  defp start_reporter(options) do
    config = Map.merge(@default_options, options)
    {:ok, pid} = TelemetryMetricsInfluxDB.start_link(config)
    pid
  end
end
