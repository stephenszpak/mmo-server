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
    player = unique_string("thrall")
    _pid = start_shared(Player, %{player_id: player, zone_id: "elwynn"})
    Player.move(player, {95, 0, 0})
    eventually(fn ->
      assert {95.0, 0.0, 0.0} == Player.get_position(player)
    end)

    Player.move(player, {10, 0, 0})

    eventually(fn ->
      assert {105.0, 0.0, 0.0} == Player.get_position(player)
      assert "durotar" == Repo.get!(PlayerPersistence, player).zone_id
    end)

    assert_receive {:join, ^player}
  end
end
