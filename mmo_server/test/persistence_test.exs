defmodule MmoServer.PersistenceTest do
  use ExUnit.Case, async: false

  alias MmoServer.{Player, PlayerPersistence, Repo}
  import MmoServer.TestHelpers

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    Repo.delete_all(PlayerPersistence)
    MmoServer.ZoneManager.ensure_zone_started("elwynn")
    :ok
  end

  test "player state persists across lifecycle" do
    zone_id = "zone_#{System.unique_integer([:positive])}"
    player_id = "player_#{System.unique_integer([:positive])}"

    pid = start_shared(Player, %{player_id: player_id, zone_id: zone_id})
    Player.move(player_id, {1.0, 2.0, 3.0})
    Player.get_position(player_id)
    p = Repo.get!(PlayerPersistence, player_id)
    assert {p.x, p.y, p.z} == {1.0, 2.0, 3.0}

    Player.damage(player_id, 200)
    Player.respawn(player_id)
    Player.get_status(player_id)
    p = Repo.get!(PlayerPersistence, player_id)
    assert p.hp == 100
    assert p.status == "alive"

    Process.exit(pid, :kill)
    pid2 = start_shared(Player, %{player_id: player_id, zone_id: zone_id})
    state = :sys.get_state(pid2)
    assert state.hp == 100
    assert state.status == :alive
    assert state.pos == {0.0, 0.0, 0.0}
  end
end
