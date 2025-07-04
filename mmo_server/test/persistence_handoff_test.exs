defmodule MmoServer.PersistenceHandoffTest do
  use ExUnit.Case, async: false

  alias MmoServer.{Player, PlayerPersistence, Repo, ZoneManager}
  import MmoServer.TestHelpers

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    Repo.delete_all(PlayerPersistence)
    ZoneManager.ensure_zone_started("elwynn")
    ZoneManager.ensure_zone_started("durotar")
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:durotar")
    :ok
  end

  test "player moves across zones and state is preserved" do
    _pid = start_shared(Player, %{player_id: "thrall", zone_id: "elwynn"})
    Player.move("thrall", {95, 0, 0})
    eventually(fn -> assert {95.0, 0.0, 0.0} == Player.get_position("thrall") end)

    Player.move("thrall", {10, 0, 0})

    eventually(fn ->
      assert {105.0, 0.0, 0.0} == Player.get_position("thrall")
      assert "durotar" == Repo.get!(PlayerPersistence, "thrall").zone_id
    end)

    assert_receive {:join, "thrall"}
  end
end
