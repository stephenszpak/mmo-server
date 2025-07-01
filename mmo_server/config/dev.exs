import Config

config :mmo_server, MmoServer.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "db",
  database: "mmo_server_dev",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :mmo_server, MmoServerWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "DEV_SECRET_KEY_BASE",
  watchers: []

config :mmo_server, MmoServerWeb.Endpoint, live_reload: [patterns: []]

config :logger, level: :debug
