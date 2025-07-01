defmodule MmoServerWeb.ZoneChannel do
  use Phoenix.Channel
  alias MmoServerWeb.Presence

  def join("zone:" <> _id = topic, _params, socket) do
    send(self(), :after_join)
    {:ok, assign(socket, :topic, topic)}
  end

  def handle_info(:after_join, socket) do
    Presence.track(socket, UUID.uuid4(), %{})
    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  def handle_in("move", %{"delta" => delta}, socket) do
    Phoenix.PubSub.broadcast(MmoServer.PubSub, socket.assigns.topic, {:move, delta})
    {:noreply, socket}
  end
end
