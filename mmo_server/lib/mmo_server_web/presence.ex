defmodule MmoServerWeb.Presence do
  use Phoenix.Presence,
    otp_app: :mmo_server,
    pubsub_server: MmoServer.PubSub
end
