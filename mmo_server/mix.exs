defmodule MmoServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :mmo_server,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {MmoServer.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7.21"},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.20"},
      {:libcluster, "~> 3.5"},
      {:horde, "~> 0.9"},
      {:delta_crdt_ex, "~> 0.6.5"},
      {:broadway, "~> 1.2"},
      {:off_broadway_pgmq, "~> 0.2"},
      {:absinthe, "~> 1.7"},
      {:absinthe_phoenix, "~> 2.0"},
      {:prom_ex, "~> 1.11"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end
end
