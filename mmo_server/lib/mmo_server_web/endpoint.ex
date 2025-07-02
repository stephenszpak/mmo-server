defmodule MmoServerWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :mmo_server

  @session_options [
    store: :cookie,
    key: "_mmo_server_key",
    signing_salt: "changeme"
  ]

  socket "/socket", MmoServerWeb.UserSocket,
    websocket: true,
    longpoll: false

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]]

  # Serve static files from priv/static, needed for LiveView assets
  plug Plug.Static,
    at: "/",
    from: :mmo_server,
    gzip: false,
    only: ~w(js)

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], json_decoder: Phoenix.json_library()
  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug MmoServerWeb.Router
end
