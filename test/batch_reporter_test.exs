defmodule TelemetryInfluxDB.BatchReporterTest do
  use ExUnit.Case, async: false

  alias TelemetryInfluxDB.BatchReporter

  setup_all do
    config = %{}

    {:ok, config: config}
  end

  test "does not batch by default", %{config: config} do
    test_pid = self()

    report_fn = fn events, config ->
      send(test_pid, {:test_report, events, config})
    end

    reporter = start_reporter(report_fn: report_fn)
    [event1, event2, event3] = random_events(3)

    BatchReporter.enqueue_event(reporter, event1, config)
    BatchReporter.enqueue_event(reporter, event2, config)
    BatchReporter.enqueue_event(reporter, event3, config)

    assert_receive {:test_report, [^event1], config}
    assert_receive {:test_report, [^event2], config}
    assert_receive {:test_report, [^event3], config}
  end

  test "reports events in batches based on batch size option", %{config: config} do
    test_pid = self()

    report_fn = fn events, config ->
      send(test_pid, {:test_report, events, config})
    end

    batch_size = Enum.random(1..10)

    reporter = start_reporter(report_fn: report_fn, batch_size: batch_size)

    Enum.each(1..(batch_size * 2), fn _ ->
      BatchReporter.enqueue_event(reporter, random_event(), config)
    end)

    assert_receive {:test_report, first_batch, config}
    assert_receive {:test_report, second_batch, config}

    assert length(first_batch) == batch_size
    assert length(second_batch) == batch_size
  end

  test "can report partial batches", %{config: config} do
    test_pid = self()

    report_fn = fn events, config ->
      send(test_pid, {:test_report, events, config})
    end

    reporter = start_reporter(report_fn: report_fn, batch_size: 2)

    [event1, event2, event3] = random_events(3)

    BatchReporter.enqueue_event(reporter, event1, config)
    BatchReporter.enqueue_event(reporter, event2, config)
    BatchReporter.enqueue_event(reporter, event3, config)

    assert_receive {:test_report, [^event1, ^event2], config}
    assert_receive {:test_report, [^event3], config}
  end

  test "doesn't wait for batch to fill if events come in slowly", %{config: config} do
    test_pid = self()

    report_fn = fn events, config ->
      send(test_pid, {:test_report, events, config})
    end

    reporter = start_reporter(report_fn: report_fn, batch_size: 10)

    [event1, event2, event3, event4, event5, event6] = random_events(6)

    BatchReporter.enqueue_event(reporter, event1, config)
    Process.sleep(1)
    BatchReporter.enqueue_event(reporter, event2, config)
    BatchReporter.enqueue_event(reporter, event3, config)
    Process.sleep(1)
    BatchReporter.enqueue_event(reporter, event4, config)
    BatchReporter.enqueue_event(reporter, event5, config)
    BatchReporter.enqueue_event(reporter, event6, config)

    assert_receive {:test_report, [^event1], config}
    assert_receive {:test_report, [^event2, ^event3], config}
    assert_receive {:test_report, [^event4, ^event5, ^event6], config}
  end

  test "does not call report function again if there are no remaining events to be reported", %{config: config} do
    test_pid = self()

    report_fn = fn events, config ->
      send(test_pid, {:test_report, events, config})
    end

    reporter = start_reporter(report_fn: report_fn)
    event = random_event()

    BatchReporter.enqueue_event(reporter, event, config)

    assert_receive {:test_report, [^event], config}
    refute_receive {:test_report, _, _}
  end

  test "does not try to report new events that come in while reporting is in progress", %{config: config} do
    test_pid = self()

    report_fn = fn events, config ->
      # simulate reporting delay
      Process.sleep(1)
      send(test_pid, {:test_report, events, config})
    end

    reporter = start_reporter(report_fn: report_fn, batch_size: 2)

    [event1, event2] = random_events(2)

    BatchReporter.enqueue_event(reporter, event1, config)
    BatchReporter.enqueue_event(reporter, event2, config)

    assert_receive {:test_report, [^event1, ^event2], config}
    refute_receive {:test_report, [], _}
  end

  defp start_reporter(options) do
    name = "BatchReporter#{random_number()}" |> String.to_atom()
    options = Keyword.merge([name: name], options)

    {:ok, reporter} = BatchReporter.start_link(options)

    reporter
  end

  defp random_number do
    Enum.random(1..1000) |> to_string()
  end

  defp random_events(count), do: Enum.map(1..count, fn _ -> random_event() end)

  defp random_event, do: "event #{random_number()}"
end
