defmodule MmoServer.BossPhaseBehaviorTest do
  use ExUnit.Case, async: false
  import MmoServer.TestHelpers

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MmoServer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(MmoServer.Repo, {:shared, self()})
    zone = unique_string("elwynn")
    start_shared(MmoServer.Zone, zone)
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:#{zone}")
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "combat:log")
    {:ok, zone: zone}
  end

  test "boss transitions phases and filters abilities", %{zone: zone} do
    MmoServer.WorldEvents.spawn_world_boss("Chef Regretulus, the Five-Star Fleshsmith", zone)

    assert_receive {:boss_spawned, boss_id, _name}, 500

    MmoServer.TestTickInjector.tick_npc(boss_id)
    assert_receive {:boss_ability, ^boss_id, "Sous Vide Sear", _, _}, 500

    MmoServer.NPC.damage(boss_id, 35)
    MmoServer.TestTickInjector.tick_npc(boss_id)
    assert_receive {:boss_phase, ^boss_id, 2, _}, 200
    assert_receive {:boss_ability, ^boss_id, ab, _, _}, 200
    assert ab in ["Sous Vide Sear", "Exploding Charcuterie"]

    MmoServer.TestTickInjector.tick_npc(boss_id)
    assert_receive {:boss_ability, ^boss_id, "Exploding Charcuterie", _, _}, 200

    MmoServer.NPC.damage(boss_id, 35)
    MmoServer.TestTickInjector.tick_npc(boss_id)
    assert_receive {:boss_phase, ^boss_id, 3, _}, 200
    assert_receive {:boss_ability, ^boss_id, ab2, _, _}, 200
    assert ab2 in ["Sous Vide Sear", "Exploding Charcuterie"]

    MmoServer.TestTickInjector.tick_npc(boss_id)
    assert_receive {:boss_ability, ^boss_id, "Exploding Charcuterie", _, _}, 200
    MmoServer.TestTickInjector.tick_npc(boss_id)
    assert_receive {:boss_ability, ^boss_id, "Taste of Regret", _, _}, 200
  end
end
