import Config

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") || "postgres://postgres:postgres@db/mmo_server_prod"

  config :mmo_server, MmoServer.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  secret_key_base = System.get_env("SECRET_KEY_BASE") || raise "SECRET_KEY_BASE not set"

  config :mmo_server, MmoServerWeb.Endpoint,
    url: [host: System.get_env("PHX_HOST") || "example.com", port: 80],
    http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "4000")],
    secret_key_base: secret_key_base
end
