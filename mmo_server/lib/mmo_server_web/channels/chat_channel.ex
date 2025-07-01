defmodule MmoServerWeb.ChatChannel do
  @moduledoc """
  Channel for player chat.
  """
  use Phoenix.Channel

  def join("chat:lobby", _payload, socket) do
    {:ok, socket}
  end

  def handle_in("message", %{"body" => body}, socket) do
    broadcast(socket, "message", %{"body" => body})
    {:noreply, socket}
  end
end
