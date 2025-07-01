import Config

config :mmo_server,
  ecto_repos: [MmoServer.Repo]

config :mmo_server, MmoServerWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: MmoServerWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: MmoServer.PubSub,
  live_view: [signing_salt: "MMOSALT"]

config :libcluster,
  topologies: [
    gossip: [
      strategy: Cluster.Strategy.Gossip
    ]
  ]

config :logger, :console, format: "$time $metadata[$level] $message\n"

config :phoenix, :json_library, Jason

import_config "#{Mix.env()}.exs"
