defmodule MmoServerWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :mmo_server

  socket "/socket", Phoenix.LiveView.Socket

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], json_decoder: Phoenix.json_library()
  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, store: :cookie, key: "_mmo_server_key", signing_salt: "changeme"
  plug MmoServerWeb.Router
end
