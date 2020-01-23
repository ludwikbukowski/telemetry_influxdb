defmodule TelemetryInfluxDB.MixProject do
  use Mix.Project

  @version "0.2.0"

  def project do
    [
      app: :telemetry_influxdb,
      version: "0.2.0",
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
      {:meck, git: "https://github.com/eproxus/meck", only: :test},
      {:dialyxir, "~> 0.5", only: :test, runtime: false},
      {:worker_pool, "~> 4.0.0"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "TelemetryInfluxDB",
      canonical: "http://hexdocs.pm/telemetry_influxdb",
      source_url: "https://github.com/ludwikbukowski/telemetry_influxdb",
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
      links: %{"GitHub" => "https://github.com/ludwikbukowski/telemetry_influxdb"}
    ]
  end
end
