import Config

config :mmo_server, MmoServer.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5433,
  database: "mmo_server_dev",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 20


config :mmo_server, MmoServerWeb.Endpoint,
  http: [ip: {127,0,0,1}, port: 4002],
  server: false

config :logger, level: :warning

config :mmo_server,
  world_tick_ms: 100,
  boss_every: 3,
  storm_chance: 0.0,
  npc_tick_ms: 100,
  zone_tick_ms: 100,
  debuff_tick_ms: 100
