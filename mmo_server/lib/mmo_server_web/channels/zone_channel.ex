defmodule MmoServerWeb.ZoneChannel do
  use Phoenix.Channel
  alias MmoServerWeb.Presence
  alias Ecto.UUID

  def join("zone:" <> id = topic, _params, socket) do
    send(self(), :after_join)
    {:ok, socket |> assign(:topic, topic) |> assign(:zone_id, id)}
  end

  def handle_info(:after_join, socket) do
    Phoenix.PubSub.subscribe(MmoServer.PubSub, socket.assigns.topic)
    Presence.track(socket, UUID.generate(), %{})
    push(socket, "presence_state", Presence.list(socket))

    positions = MmoServer.Zone.get_position(socket.assigns.zone_id)

    players =
      Enum.map(positions, fn {id, {x, y, z}} ->
        %{id: id, position: %{x: x, y: y, z: z}}
      end)

    push(socket, "zone_state", %{players: players})
    {:noreply, socket}
  end

  def handle_in("move", %{"delta" => delta}, socket) do
    Phoenix.PubSub.broadcast(MmoServer.PubSub, socket.assigns.topic, {:move, delta})
    {:noreply, socket}
  end

  def handle_info(%{event: event, payload: payload}, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}
end
