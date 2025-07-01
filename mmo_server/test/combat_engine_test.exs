defmodule MmoServer.CombatEngineTest do
  use ExUnit.Case, async: false

  test "player dies and respawns" do
    {:ok, _zone} = MmoServer.Zone.start_link("zone1")
    {:ok, _a} = MmoServer.Player.start_link(%{player_id: "a", zone_id: "zone1"})
    {:ok, _b} = MmoServer.Player.start_link(%{player_id: "b", zone_id: "zone1"})

    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:zone1")

    MmoServer.CombatEngine.start_combat("a", "b")

    assert_receive {:death, "b"}, 5_000

    assert :dead == MmoServer.Player.get_status("b")

    assert_receive {:player_respawned, "b"}, 12_000

    assert :alive == MmoServer.Player.get_status("b")
    assert 100 == (:sys.get_state({:via, Horde.Registry, {PlayerRegistry, "b"}}).hp)
  end
end
