# telemetry_influxdb
InfluxDB reporter for [Telemetry](https://github.com/beam-telemetry/telemetry)

`Telemetry` reporter for InfluxDB compatibile events.

  To use it, start the reporter with the `start_link/1` function, providing it a list of
  `Telemetry` event names:

  ```elixir
      TelemetryInfluxDB.start_link(
        events: [
          %{name: [:memory, :usage]},
          %{name: [:http, :request]},
        ]
      )
  ```

  or put it under a supervisor:

  ```elixir
  children = [
    {TelemetryInfluxDB, [
      events:  events: [
        %{name: [:memory, :usage]},
        %{name: [:http, :request]}
    ]}
  ]

  Supervisor.start_link(children, ...)
  ```

  By default the reporter sends events through UDP to localhost:8089.

  Note that the reporter doesn't aggregate events in-process - it sends updates to InfluxDB
  whenever a relevant Telemetry event is emitted.

## Run test
```
$ make test
```

It should setup the latest InfluxDB in docker and run all the tests against it.

## Configuration

Possible options for the reporter:

 - `:reporter_name` - unique name for the reporter. The purpose is to distinguish between different reporters running in the system.
    One can run separate independent InfluxDB reporters, with different configurations and goals.
 -  `:protocol` - :udp or :http. Which protocol to use for connecting to InfluxDB. Default option is :udp.
 -  `:host` - host, where InfluxDB is running.
 -  `:port` - port, where InfluxDB is running.
 -  `:db` - name of InfluxDB's  instance.
 -  `:username` - username of InfluxDB's user that has writes privileges.
 -   `:password` - password for the user.
 - `:events` - list of `Telemetry` events' names that we want to send to InfluxDB.
    Each event should be specified by the map with the field `name`, e.g. `%{name: [:sample, :event, :name]}`.
    Event names should be compatible with `Telemetry` events' format.
 - `:tags` - list of global tags, that will be attached to each reported event. The format is a map,
    where the key and the value are tag's name and value, respectively.
    Both the tag's name and the value could be atoms or binaries.

## Notes

For the HTTP protocol, [worker_pool](https://github.com/inaka/worker_pool) is used for sending requests asynchronously.
Therefore the HTTP requests are sent in the context of the separate workers' pool, which does not block the client's application
(it is not sent in the critical path of the client's process).
The events are sent straightaway without any batching techniques.
On the other hand, UDP packets are sent in the context of the processes that execute the events.
However, the lightweight nature of UDP should not cause any bottlenecks in such a solution.

Once the reporter is started, it is attached to specified `Telemetry` events.
The events are detached when the reporter is shutdown.

## Copyright and License

TelemetryInfluxDB is copyright (c) 2019 Ludwik Bukowski.

TelemetryInfluxDB source code is released under MIT license.

See [LICENSE](LICENSE) for more information.

