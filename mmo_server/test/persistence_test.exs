defmodule MmoServer.PersistenceTest do
  use ExUnit.Case, async: false

  alias MmoServer.{PlayerPersistence, Repo}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    {:ok, _} = start_supervised(MmoServer.Player.PersistenceQueue)
    {:ok, _} = start_supervised(MmoServer.Player.PersistenceBroadway)
    {:ok, _zone} = MmoServer.Zone.start_link("elwynn")
    :ok
  end

  test "player state persisted and loaded" do
    {:ok, pid} = MmoServer.Player.start_link(%{player_id: "thrall", zone_id: "elwynn"})
    MmoServer.Player.damage("thrall", 30)
    :timer.sleep(200)

    persisted = Repo.get(PlayerPersistence, "thrall")
    assert persisted.hp == 70

    Process.exit(pid, :kill)
    {:ok, pid2} = MmoServer.Player.start_link(%{player_id: "thrall", zone_id: "elwynn"})
    state = :sys.get_state(pid2)
    assert state.hp == 70
  end
end
