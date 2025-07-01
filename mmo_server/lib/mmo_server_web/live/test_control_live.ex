defmodule MmoServerWeb.TestControlLive do
  use Phoenix.LiveView, layout: false

  alias MmoServer.{Player, CombatEngine}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(1000, :refresh)

    players =
      Horde.Registry.select(PlayerRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
      |> Enum.filter(&is_binary/1)

    {:ok,
     assign(socket,
       players: players,
       selected_player: List.first(players),
       target_player: List.first(players)
     )}
  end

  @impl true
  def handle_event("update", %{"selected_player" => sel, "target_player" => tgt}, socket) do
    {:noreply, assign(socket, selected_player: sel, target_player: tgt)}
  end

  def handle_event("move", %{"dx" => dx, "dy" => dy, "dz" => dz}, socket) do
    player = socket.assigns.selected_player
    {dx, dy, dz} = {String.to_integer(dx), String.to_integer(dy), String.to_integer(dz)}
    Player.move(player, {dx, dy, dz})
    {:noreply, socket}
  end

  def handle_event("start_combat", _params, socket) do
    CombatEngine.start_combat(socket.assigns.selected_player, socket.assigns.target_player)
    {:noreply, socket}
  end

  def handle_event("damage", _params, socket) do
    Player.damage(socket.assigns.selected_player, 100)
    {:noreply, socket}
  end

  def handle_event("respawn", _params, socket) do
    Player.respawn(socket.assigns.selected_player)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    players =
      Horde.Registry.select(PlayerRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
      |> Enum.filter(&is_binary/1)

    selected =
      if socket.assigns.selected_player in players do
        socket.assigns.selected_player
      else
        List.first(players)
      end

    target =
      if socket.assigns.target_player in players do
        socket.assigns.target_player
      else
        List.first(players)
      end

    {:noreply,
     assign(socket,
       players: players,
       selected_player: selected,
       target_player: target
     )}
  end

  # Rendered via "test_control_live.html.heex"
  # No custom rendering logic required here
end
