defmodule MmoServerWeb.UserSocket do
  use Phoenix.Socket

  channel "zone:*", MmoServerWeb.ZoneChannel
  channel "chat:global", MmoServerWeb.ChatChannel

  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  def id(_socket), do: nil
end
