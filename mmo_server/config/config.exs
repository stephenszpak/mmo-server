import Config

config :mmo_server,
  ecto_repos: [MmoServer.Repo]

config :mmo_server, MmoServerWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: MmoServerWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: MmoServer.PubSub,
  live_view: [signing_salt: "changeme"]

config :libcluster,
  topologies: [
    local_gossip: [
      strategy: Cluster.Strategy.Gossip
    ]
  ]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
