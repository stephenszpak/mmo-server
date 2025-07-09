defmodule MmoServer.BossTickBehaviorTest do
  use ExUnit.Case, async: false
  import MmoServer.TestHelpers

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MmoServer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(MmoServer.Repo, {:shared, self()})
    zone = unique_string("elwynn")
    start_shared(MmoServer.Zone, zone)
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "combat:log")
    {:ok, zone: zone}
  end

  test "boss cycles abilities and damages players", %{zone: zone} do
    player = unique_string("p")
    start_shared(MmoServer.Player, %{player_id: player, zone_id: zone})

    MmoServer.WorldEvents.spawn_world_boss("Chef Regretulus, the Five-Star Fleshsmith", zone)

    assert_receive {:boss_spawned, _name}, 500
    hp = MmoServer.Player.get_hp(player)

    assert_receive {:boss_ability, _id, _ability, _desc, _type}, 1_500
    eventually(fn -> assert MmoServer.Player.get_hp(player) < hp end)
  end
end
