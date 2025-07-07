defmodule MmoServerWeb.TestDashboardLive do
  use Phoenix.LiveView, layout: false

  alias MmoServer.{Player, NPC, WorldEvents, InstanceManager, ZoneMap}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MmoServer.PubSub, "world:clock")
      subscribe_zones(base_zones())
      subscribe_zones(InstanceManager.active_instances())
    end

    {:ok,
     socket
     |> assign(:players, fetch_players())
     |> assign(:zones, base_zones())
     |> assign(:npcs, fetch_npcs())
     |> assign(:instances, InstanceManager.active_instances())
     |> assign(:selected_player, nil)
     |> assign(:logs, [])}
  end

  defp base_zones do
    Map.keys(ZoneMap.zones())
  end

  defp subscribe_zones(ids) do
    Enum.each(ids, fn id ->
      Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:#{id}")
    end)
  end

  defp fetch_players do
    Horde.Registry.select(PlayerRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&player_info/1)
  end

  defp player_info(id) do
    case Horde.Registry.lookup(PlayerRegistry, id) do
      [{pid, _}] ->
        if Process.alive?(pid) do
          try do
            s = :sys.get_state(pid)
            %{id: id, zone: s.zone_id, hp: s.hp, status: s.status}
          catch
            _, _ -> %{id: id, zone: nil, hp: nil, status: nil}
          end
        else
          %{id: id, zone: nil, hp: nil, status: nil}
        end

      _ ->
        %{id: id, zone: nil, hp: nil, status: nil}
    end
  end

  defp fetch_npcs do
    Horde.Registry.select(NPCRegistry, [{{{:npc, :"$1"}, :_, :_}, [], [:"$1"]}])
    |> Enum.map(&npc_info/1)
  end

  defp npc_info(id) do
    case Horde.Registry.lookup(NPCRegistry, {:npc, id}) do
      [{pid, _}] ->
        if Process.alive?(pid) do
          try do
            s = :sys.get_state(pid)
            %{id: id, zone: s.zone_id, type: s.type, hp: s.hp}
          catch
            _, _ -> %{id: id, zone: nil, type: nil, hp: nil}
          end
        else
          %{id: id, zone: nil, type: nil, hp: nil}
        end

      _ ->
        %{id: id, zone: nil, type: nil, hp: nil}
    end
  end

  defp log(socket, msg) do
    assign(socket, :logs, ([msg | socket.assigns.logs] |> Enum.take(50)))
  end

  # Player selection
  @impl true
  def handle_event("select_player", %{"player" => id}, socket) do
    {:noreply, assign(socket, :selected_player, id)}
  end

  # Player movement
  def handle_event("move", %{"dir" => dir}, %{assigns: %{selected_player: id}} = socket) when is_binary(id) do
    delta =
      case dir do
        "north" -> {0, 1, 0}
        "south" -> {0, -1, 0}
        "east" -> {1, 0, 0}
        "west" -> {-1, 0, 0}
        _ -> {0, 0, 0}
      end

    Player.move(id, delta)
    {:noreply, socket}
  end

  def handle_event("damage", _params, %{assigns: %{selected_player: id}} = socket) when is_binary(id) do
    Player.damage(id, 50)
    {:noreply, socket}
  end

  def handle_event("respawn", _params, %{assigns: %{selected_player: id}} = socket) when is_binary(id) do
    Player.respawn(id)
    {:noreply, socket}
  end

  def handle_event("kill", _params, %{assigns: %{selected_player: id}} = socket) when is_binary(id) do
    Player.stop(id)
    {:noreply, socket}
  end

  # World events
  def handle_event("world_boss", _params, socket) do
    WorldEvents.spawn_world_boss()
    {:noreply, socket |> log("World boss spawned")}
  end

  def handle_event("storm", _params, socket) do
    WorldEvents.storm_event()
    {:noreply, socket |> log("Storm triggered")}
  end

  def handle_event("merchant", _params, socket) do
    WorldEvents.rotate_merchant_inventory()
    {:noreply, socket |> log("Merchant inventory rotated")}
  end

  def handle_event("start_instance", %{"base_zone" => zone, "players" => players}, socket) do
    {:ok, id} = InstanceManager.start_instance(zone, players)
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:#{id}")
    {:noreply, socket |> log("Instance #{id} started") |> refresh_state()}
  end

  @impl true
  def handle_info({:tick, count} = msg, socket) do
    IO.inspect(msg, label: "LiveView Event")
    {:noreply, socket |> log("tick #{count}") |> refresh_state()}
  end

  def handle_info({:spawn_world_boss, zone} = msg, socket) do
    IO.inspect(msg, label: "LiveView Event")
    {:noreply, socket |> log("spawn_world_boss #{zone}") |> refresh_state()}
  end

  def handle_info({:player_moved, id, pos} = msg, socket) do
    IO.inspect(msg, label: "LiveView Event")
    {:noreply, socket |> log("player #{id} moved to #{inspect(pos)}") |> refresh_state()}
  end

  def handle_info({:npc_moved, id, pos} = msg, socket) do
    IO.inspect(msg, label: "LiveView Event")
    {:noreply, socket |> log("npc #{id} moved to #{inspect(pos)}") |> refresh_state()}
  end

  def handle_info({:zone_event, event} = msg, socket) do
    IO.inspect(msg, label: "LiveView Event")
    {:noreply, socket |> log("zone_event #{inspect(event)}") |> refresh_state()}
  end

  def handle_info({:instance_started, id} = msg, socket) do
    IO.inspect(msg, label: "LiveView Event")
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:#{id}")
    {:noreply, socket |> log("instance_started #{id}") |> refresh_state()}
  end

  def handle_info({:instance_shutdown, id} = msg, socket) do
    IO.inspect(msg, label: "LiveView Event")
    {:noreply, socket |> log("instance_shutdown #{id}") |> refresh_state()}
  end

  def handle_info(msg, socket) do
    IO.inspect(msg, label: "LiveView Event")
    text = inspect(msg)
    {:noreply, socket |> log(text) |> refresh_state()}
  end

  defp refresh_state(socket) do
    socket
    |> assign(:players, fetch_players())
    |> assign(:npcs, fetch_npcs())
    |> assign(:instances, InstanceManager.active_instances())
  end
end
