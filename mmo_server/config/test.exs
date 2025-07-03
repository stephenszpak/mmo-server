import Config

config :mmo_server, MmoServer.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5433,
  database: "mmo_server_test",
  pool: Ecto.Adapters.SQL.Sandbox

config :mmo_server, MmoServer.PostgresPool,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5433,
  database: "mmo_server_test"

config :mmo_server, MmoServerWeb.Endpoint,
  http: [ip: {127,0,0,1}, port: 4002],
  server: false

config :logger, level: :warning
