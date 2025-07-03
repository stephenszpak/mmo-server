defmodule MmoServer.PersistenceTest do
  use ExUnit.Case, async: false

  alias MmoServer.{Player, PlayerPersistence, Repo}
  import MmoServer.TestHelpers

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    start_shared(MmoServer.Zone, "elwynn")
    :ok
  end

  test "player state persists across lifecycle" do
    pid = start_shared(Player, %{player_id: "thrall", zone_id: "elwynn"})
    Player.move("thrall", {1.0, 2.0, 3.0})

    eventually(fn ->
      p = Repo.get!(PlayerPersistence, "thrall")
      assert {p.x, p.y, p.z} == {1.0, 2.0, 3.0}
    end)

    Player.damage("thrall", 200)
    Player.respawn("thrall")

    eventually(fn ->
      p = Repo.get!(PlayerPersistence, "thrall")
      assert p.hp == 100
      assert p.status == "alive"
    end)

    Process.exit(pid, :kill)
    pid2 = start_shared(Player, %{player_id: "thrall", zone_id: "elwynn"})
    state = :sys.get_state(pid2)
    assert state.hp == 100
    assert state.status == :alive
    assert state.pos == {0.0, 0.0, 0.0}
  end
end
