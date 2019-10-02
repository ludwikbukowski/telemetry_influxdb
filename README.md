# telemetry_influxdb
InfluxDB reporter for Telemetry

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

  By default the reporter sends events through UDP to localhost:8086.

  Note that the reporter doesn't aggregate events in-process - it sends updates to InfluxDB
  whenever a relevant Telemetry event is emitted.

## Run test
```
$ make test
```

It should setup the latest InfluxDB in docker and run all the tests against it.

## Copyright and License

TelemetryInfluxDB is copyright (c) 2019 Ludwik Bukowski.

TelemetryInfluxDB source code is released under MIT license.

See [LICENSE](LICENSE) for more information.

