defmodule MmoServerWeb.TestDashboardLive do
  use Phoenix.LiveView, layout: false

  require Logger
  alias MmoServer.{Player, WorldEvents, InstanceManager, ZoneMap, MobTemplate, LootSystem, WorldState}
  alias MmoServer.Zone.SpawnController
  alias MmoServer.Zone
  alias MmoServer.Player.Inventory

  @impl true
  def mount(_params, _session, socket) do
    Logger.debug("LiveView mounted \u2013 connected? #{connected?(socket)}")

    if connected?(socket) do
      Phoenix.PubSub.subscribe(MmoServer.PubSub, "world:clock")
      Phoenix.PubSub.subscribe(MmoServer.PubSub, "world:state")
      subscribe_all_zones()
    end

    socket =
      socket
      |> assign(:players, fetch_players())
      |> assign(:zones, base_zones())
      |> assign(:npcs, fetch_npcs())
      |> assign(:instances, InstanceManager.active_instances())
      |> assign(:gm_zones, base_zones())
      |> assign(:gm_players, fetch_players())
      |> assign(:gm_templates, fetch_templates())
        |> assign(:gm_zone, List.first(base_zones()))
        |> assign(:gm_template, List.first(fetch_templates()))
      |> assign(:gm_player, nil)
      |> assign(:selected_player, nil)
      |> assign(:inventory, [])
      |> assign(:equipped, [])
      |> assign(:world_state, WorldState.all())
      |> assign(:live_connected, connected?(socket))
      |> assign(:last_log, System.system_time(:millisecond))
      |> assign(:logs, [])
      |> log("LiveView mounted")

    {:ok, socket}
  end

  defp base_zones do
    Map.keys(ZoneMap.zones())
  end

  defp subscribe_all_zones do
    Horde.Registry.select(PlayerRegistry, [{{{:zone, :"$1"}, :_, :_}, [], [:"$1"]}])
    |> Enum.each(fn id ->
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

  defp fetch_templates do
    MobTemplate.list()
    |> Enum.map(& &1.id)
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
    now = System.system_time(:millisecond)
    last = socket.assigns[:last_log] || 0

    if now - last >= 15_000 do
      socket
      |> assign(:logs, ([msg | socket.assigns.logs] |> Enum.take(50)))
      |> assign(:last_log, now)
    else
      socket
    end
  end

  # Player selection
  @impl true
  def handle_event("select_player", %{"player" => id}, socket) do
    Logger.debug("Select player: #{inspect(id)}")
    {:noreply,
     socket
     |> assign(:selected_player, id)
     |> refresh_inventory(id)}
  end

  # Player movement
  def handle_event("move", %{"dir" => dir}, %{assigns: %{selected_player: id}} = socket) when is_binary(id) do
    Logger.debug("Move event: #{inspect({id, dir})}")
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
    Logger.debug("Damage event for #{id}")
    Player.damage(id, 50)
    {:noreply, socket}
  end

  def handle_event("respawn", _params, %{assigns: %{selected_player: id}} = socket) when is_binary(id) do
    Logger.debug("Respawn event for #{id}")
    Player.respawn(id)
    {:noreply, socket}
  end

  def handle_event("kill", _params, %{assigns: %{selected_player: id}} = socket) when is_binary(id) do
    Logger.debug("Kill event for #{id}")
    Player.kill(id)
    {:noreply, socket}
  end

  def handle_event("equip", %{"item_id" => item_id}, %{assigns: %{selected_player: player_id}} = socket)
      when is_binary(player_id) do
    Logger.debug("Equip item #{item_id} for #{player_id}")
    Inventory.equip(player_id, item_id)
    {:noreply, refresh_inventory(socket, player_id)}
  end

  def handle_event("unequip", %{"slot" => slot}, %{assigns: %{selected_player: player_id}} = socket)
      when is_binary(player_id) do
    Logger.debug("Unequip slot #{slot} for #{player_id}")
    Inventory.unequip(player_id, slot)
    {:noreply, refresh_inventory(socket, player_id)}
  end

  # World events
  def handle_event("world_boss", _params, socket) do
    Logger.debug("World boss event")
    WorldEvents.spawn_world_boss()
    {:noreply, socket |> log("World boss spawned")}
  end

  def handle_event("storm", _params, socket) do
    Logger.debug("Storm event")
    WorldEvents.storm_event()
    {:noreply, socket |> log("Storm triggered")}
  end

  def handle_event("merchant", _params, socket) do
    Logger.debug("Merchant event")
    WorldEvents.rotate_merchant_inventory()
    {:noreply, socket |> log("Merchant inventory rotated")}
  end

  def handle_event("toggle_state", %{"key" => key}, socket) do
    if WorldState.get(key) == "true" do
      WorldState.delete(key)
    else
      WorldState.put(key, "true")
    end

    {:noreply, socket}
  end

  def handle_event("start_instance", %{"base_zone" => zone, "players" => players}, socket) do
    Logger.debug("Start instance: #{inspect(zone)} players: #{inspect(players)}")
    {:ok, id} = InstanceManager.start_instance(zone, players)
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:#{id}")
    {:noreply, socket |> log("Instance #{id} started") |> refresh_state()}
  end

  def handle_event("gm_select", params, socket) do
    zone = Map.get(params, "zone", socket.assigns.gm_zone)
    template = Map.get(params, "template", socket.assigns.gm_template)
    player = Map.get(params, "player", socket.assigns.gm_player)

    {:noreply,
     socket
     |> assign(:gm_zone, zone)
     |> assign(:gm_template, template)
     |> assign(:gm_player, player)}
  end

  # GM tools
  def handle_event("gm_spawn_npc", %{"zone" => zone, "template" => template}, socket) do
    Logger.debug("[GM] Spawn NPC #{template} in #{zone}")
    SpawnController.spawn_from_template(zone, template)
    {:noreply, socket |> log("spawned #{template} in #{zone}") |> refresh_state()}
  end

  def handle_event("gm_kill_all", %{"zone" => zone}, socket) do
    Logger.debug("[GM] Kill all NPCs in #{zone}")
    Zone.kill_all_npcs(zone)
    {:noreply, socket |> log("kill_all #{zone}") |> refresh_state()}
  end

  def handle_event("gm_force_spawn", %{"zone" => zone}, socket) do
    Logger.debug("[GM] Force spawn wave in #{zone}")
    SpawnController.force_spawn_wave(zone)
    {:noreply, socket |> log("force_spawn #{zone}") |> refresh_state()}
  end

  def handle_event("gm_xp", %{"player" => player}, socket) do
    Logger.debug("[GM] Give XP to #{player}")
    Player.XP.gain(player, 50)
    {:noreply, socket |> log("gave 50 xp to #{player}") |> refresh_state()}
  end

  def handle_event("gm_drop_loot", %{"zone" => zone, "template" => item}, socket) do
    Logger.debug("[GM] Drop loot #{item} in #{zone}")
    LootSystem.spawn(zone, item)
    {:noreply, socket |> log("loot #{item} at #{zone}") |> refresh_state()}
  end

  def handle_event("gm_kill_player", %{"player" => player}, socket) do
    Logger.debug("[GM] Kill player #{player}")
    Player.kill(player)
    {:noreply, socket |> log("killed player #{player}") |> refresh_state()}
  end

  def handle_event("gm_resurrect", %{"player" => player}, socket) do
    Logger.debug("[GM] Resurrect player #{player}")
    Player.resurrect(player)
    {:noreply, socket |> log("resurrected #{player}") |> refresh_state()}
  end

  def handle_event("gm_teleport", %{"player" => player, "zone" => zone}, socket) do
    Logger.debug("[GM] Teleport #{player} to #{zone}")
    Player.teleport(player, zone)
    {:noreply, socket |> log("teleported #{player} to #{zone}") |> refresh_state()}
  end

  def handle_event("log_test", _params, socket) do
    Logger.debug("Test event triggered")
    {:noreply, log(socket, "Test event triggered")}
  end

  def handle_event(event, params, socket) do
    Logger.warning("Unhandled event: #{event}, #{inspect(params)}")
    {:noreply, socket}
  end

  @impl true
  def handle_info({:tick, count} = msg, socket) do
    Logger.debug("LiveView Event: #{inspect(msg)}")
    {:noreply, socket |> log("tick #{count}") |> refresh_state()}
  end

  def handle_info({:spawn_world_boss, zone} = msg, socket) do
    Logger.debug("LiveView Event: #{inspect(msg)}")
    {:noreply, socket |> log("spawn_world_boss #{zone}") |> refresh_state()}
  end

  def handle_info({:player_moved, id, pos} = msg, socket) do
    Logger.debug("LiveView Event: #{inspect(msg)}")
    {:noreply, socket |> log("player #{id} moved to #{inspect(pos)}") |> refresh_state()}
  end

  def handle_info({:npc_moved, id, pos} = msg, socket) do
    Logger.debug("LiveView Event: #{inspect(msg)}")
    {:noreply, socket |> log("npc #{id} moved to #{inspect(pos)}") |> refresh_state()}
  end

  def handle_info({:zone_event, event} = msg, socket) do
    Logger.debug("LiveView Event: #{inspect(msg)}")
    {:noreply, socket |> log("zone_event #{inspect(event)}") |> refresh_state()}
  end

  def handle_info({:instance_started, id} = msg, socket) do
    Logger.debug("LiveView Event: #{inspect(msg)}")
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:#{id}")
    {:noreply, socket |> log("instance_started #{id}") |> refresh_state()}
  end

  def handle_info({:instance_shutdown, id} = msg, socket) do
    Logger.debug("LiveView Event: #{inspect(msg)}")
    {:noreply, socket |> log("instance_shutdown #{id}") |> refresh_state()}
  end

  def handle_info({:world_state_changed, key, value}, socket) do
    {:noreply, assign(socket, :world_state, Map.put(socket.assigns.world_state, key, value))}
  end

  def handle_info({:world_state_deleted, key}, socket) do
    {:noreply, assign(socket, :world_state, Map.delete(socket.assigns.world_state, key))}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, refresh_state(socket)}
  end

  defp refresh_state(socket) do
    socket
    |> assign(:players, fetch_players())
    |> assign(:npcs, fetch_npcs())
    |> assign(:instances, InstanceManager.active_instances())
    |> assign(:gm_players, fetch_players())
    |> assign(:gm_zones, base_zones())
    |> assign(:gm_templates, fetch_templates())
    |> assign(:world_state, WorldState.all())
    |> assign_new(:gm_zone, fn -> List.first(base_zones()) end)
    |> assign_new(:gm_template, fn -> List.first(fetch_templates()) end)
    |> assign_new(:gm_player, fn -> nil end)
  end

  defp refresh_inventory(socket, player_id) do
    socket
    |> assign(:inventory, Inventory.list(player_id))
    |> assign(:equipped, Inventory.get_equipped(player_id))
  end

  defp quality_color("epic"), do: "text-purple-700"
  defp quality_color("rare"), do: "text-green-600"
  defp quality_color(_), do: "text-gray-700"
end
