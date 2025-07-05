defmodule MmoServer.PersistenceTest do
  use ExUnit.Case, async: false

  alias MmoServer.{Player, PlayerPersistence, Repo}
  import MmoServer.TestHelpers

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    Repo.delete_all(PlayerPersistence)
    zone_id = unique_string("elwynn")
    start_shared(MmoServer.Zone, zone_id)
    %{zone_id: zone_id}
  end

  test "player state persists across lifecycle", %{zone_id: zone_id} do
    player = unique_string("thrall")
    pid = start_shared(Player, %{player_id: player, zone_id: zone_id})
    Player.move(player, {1.0, 2.0, 3.0})

    eventually(fn ->
      p = Repo.get!(PlayerPersistence, player)
      assert {p.x, p.y, p.z} == {1.0, 2.0, 3.0}
    end)

    Player.damage(player, 200)
    Player.respawn(player)

    eventually(fn ->
      p = Repo.get!(PlayerPersistence, player)
      assert p.hp == 100
      assert p.status == "alive"
    end)

    Process.exit(pid, :kill)
    pid2 = start_shared(Player, %{player_id: player, zone_id: zone_id})
    state = :sys.get_state(pid2)
    assert state.hp == 100
    assert state.status == :alive
    assert state.pos == {0.0, 0.0, 0.0}
  end
end
