defmodule MmoServer.PersistenceTest do
  use ExUnit.Case, async: false

  alias MmoServer.{PlayerPersistence, Repo}

  import MmoServer.TestHelpers

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    b = Process.whereis(MmoServer.Player.PersistenceBroadway)
    allow_tree(Repo, self(), b)
    start_shared(MmoServer.Zone, "elwynn")
    :ok
  end

  test "player state persisted and loaded" do
    pid = start_shared(MmoServer.Player, %{player_id: "thrall", zone_id: "elwynn"})
    MmoServer.Player.damage("thrall", 30)

    eventually(fn ->
      assert 70 == Repo.get!(PlayerPersistence, "thrall").hp
    end)

    Process.exit(pid, :kill)
    pid2 = start_shared(MmoServer.Player, %{player_id: "thrall", zone_id: "elwynn"})
    state = :sys.get_state(pid2)
    assert state.hp == 70
  end
end

