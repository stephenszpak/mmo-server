defmodule MmoServer.CombatEngineTest do
  use ExUnit.Case, async: false

  import MmoServer.TestHelpers

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MmoServer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(MmoServer.Repo, {:shared, self()})
    :ok
  end

  test "player dies and respawns" do
    start_shared(MmoServer.Zone, "zone1")
    start_shared(MmoServer.Player, %{player_id: "a", zone_id: "zone1"})
    start_shared(MmoServer.Player, %{player_id: "b", zone_id: "zone1"})

    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:zone1")

    MmoServer.CombatEngine.start_combat("a", "b")

    assert_receive {:death, "b"}, 5_000

    assert :dead == MmoServer.Player.get_status("b")

    assert_receive {:player_respawned, "b"}, 12_000

    assert :alive == MmoServer.Player.get_status("b")
    assert 100 == (:sys.get_state({:via, Horde.Registry, {PlayerRegistry, "b"}}).hp)
  end
end
