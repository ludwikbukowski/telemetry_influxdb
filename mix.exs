defmodule TelemetryMetricsInfluxDB.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :telemetry_metrics_influxdb,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      preferred_cli_env: preferred_cli_env(),
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp preferred_cli_env do
    [
      docs: :docs,
      dialyzer: :test
    ]
  end

  defp elixirc_paths(:test), do: ["lib/", "test/support/"]
  defp elixirc_paths(_), do: ["lib/"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:telemetry, "~> 0.4.0"},
      {:jason, "~> 1.0"},
      {:httpoison, "~> 1.5"},
      {:eventually, git: "https://github.com/distributed-owls/eventually", only: :test},
      {:dialyxir, "~> 0.5", only: :test, runtime: false},
      {:worker_pool, git: "https://github.com/inaka/worker_pool"},
      {:ex_doc, "~> 0.19", only: :docs}
    ]
  end

  defp docs do
    [
      main: "TelemetryMetricsInfluxDB",
      canonical: "http://hexdocs.pm/telemetry_metrics_influxdb",
      source_url: "https://github.com/ludwikbukowski/telemetry_metrics_influxdb",
      source_ref: "v#{@version}"
    ]
  end

  defp description do
    """
    Telemetry.Metrics reporter for InfluxDB
    """
  end

  defp package do
    [
      maintainers: ["Ludwik Bukowski"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/ludwikbukowski/telemetry_metrics_influxdb"}
    ]
  end
end
