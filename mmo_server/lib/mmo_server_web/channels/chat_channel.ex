defmodule MmoServerWeb.ChatChannel do
  use Phoenix.Channel

  def join("chat:global", _params, socket) do
    {:ok, socket}
  end

  def handle_in("msg", %{"body" => body}, socket) do
    broadcast!(socket, "msg", %{body: body})
    {:noreply, socket}
  end
end
