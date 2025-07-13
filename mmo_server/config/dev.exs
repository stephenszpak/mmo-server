import Config

config :mmo_server, MmoServer.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5433,
  database: "mmo_server_dev",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10


config :mmo_server, MmoServerWeb.Endpoint,
  http: [ip: {127,0,0,1}, port: 4001],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: String.duplicate("a", 64),
  watchers: []

config :mmo_server, MmoServerWeb.Endpoint,
  live_reload: [patterns: [~r"priv/static/.*", ~r"priv/gettext/.*", ~r"lib/mmo_server_web/(controllers|live|components)/.*"]]

config :logger, :console,
  format: "[$level] $message\n",
  level: :info
