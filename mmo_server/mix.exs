defmodule MmoServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :mmo_server,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix]],
      aliases: aliases()
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
      {:phoenix, "~> 1.7"},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:ecto_sql, "~> 3.11"},
      {:postgrex, ">= 0.17.0"},
      {:libcluster, "~> 3.3"},
      {:horde, "~> 0.8"},
      {:delta_crdt, "~> 0.6"},
      {:broadway, "~> 1.0"},
      {:nimble_pool, "~> 1.1"},
      {:absinthe, "~> 1.7"},
      {:absinthe_phoenix, "~> 2.0"},
      {:plug_cowboy, "~> 2.6"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:prom_ex, "~> 1.9"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      ci: ["deps.get", "compile --warnings-as-errors", "test", "credo --strict"]
    ]
  end
end
