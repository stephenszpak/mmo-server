import Config

config :mmo_server, MmoServer.Repo,
  ssl: false,
  pool_size: 15

config :mmo_server, MmoServerWeb.Endpoint,
  url: [host: "example.com", port: 80],
  secret_key_base: """#{String.duplicate("b", 64)}""",
  cache_static_manifest: "priv/static/cache_manifest.json"
