defmodule TelemetryMetricsInfluxDB.MixProject do
  use Mix.Project

  def project do
    [
      app: :telemetry_metrics_influxdb,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib/", "test/support/", "test/real/support/"]
  defp elixirc_paths(:real_test), do: ["lib/", "test/support/", "test/real/support/"]
  defp elixirc_paths(_), do: ["lib/"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:telemetry_metrics, "~> 0.3"},
      {:plug_cowboy, "~> 2.0"},
      {:jason, "~> 1.0"},
      {:httpoison, "~> 1.5"}
    ]
  end

end
