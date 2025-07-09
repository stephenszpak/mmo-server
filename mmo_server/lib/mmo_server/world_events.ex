defmodule MmoServer.WorldEvents do
  @moduledoc """
  Dispatches world-level events to players and zones.
  """

  alias MmoServer.{PubSub, ZoneMap, BossMetadata, ZoneManager}
  alias MmoServer.Zone.NPCSupervisor

  @spec spawn_world_boss(String.t() | nil) :: :ok
  def spawn_world_boss(name \\ nil) do
    boss = if name, do: BossMetadata.get_boss(name), else: BossMetadata.random_boss()
    zone_id = "elwynn"
    ZoneManager.ensure_zone_started(zone_id)

    [{zone_pid, _}] = Horde.Registry.lookup(PlayerRegistry, {:zone, zone_id})
    %{npc_sup: npc_sup} = :sys.get_state(zone_pid)

    id = "boss_#{System.unique_integer([:positive])}"
    npc = %{
      id: id,
      zone_id: zone_id,
      template_id: "dungeon_boss",
      type: :boss,
      boss_name: boss["name"],
      behavior: :aggressive
    }

    NPCSupervisor.start_npc(npc_sup, npc)
    Phoenix.PubSub.broadcast(PubSub, "zone:#{zone_id}", {:boss_spawned, id, boss["name"]})
    Phoenix.PubSub.broadcast(PubSub, "combat:log", {:boss_spawned, boss["name"]})
    :ok
  end

  @spec rotate_merchant_inventory() :: :ok
  def rotate_merchant_inventory do
    Phoenix.PubSub.broadcast(PubSub, "world:clock", :rotate_merchant_inventory)
    :ok
  end

  @spec storm_event() :: :ok
  def storm_event do
    Phoenix.PubSub.broadcast(PubSub, "world:clock", :storm)
    :ok
  end
end
