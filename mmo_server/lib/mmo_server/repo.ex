defmodule MmoServer.Repo do
  use Ecto.Repo,
    otp_app: :mmo_server,
    adapter: Ecto.Adapters.Postgres
end
