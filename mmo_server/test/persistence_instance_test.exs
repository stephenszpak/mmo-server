defmodule MmoServer.PersistenceInstanceTest do
  use ExUnit.Case, async: false

  alias MmoServer.{InstanceManager, Player, PlayerPersistence, Repo}
  import MmoServer.TestHelpers

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    Repo.delete_all(PlayerPersistence)
    zone_id = unique_string("elwynn")
    start_shared(MmoServer.Zone, zone_id)
    %{zone_id: zone_id}
  end

  test "player state persists when entering instance", %{zone_id: zone_id} do
    player = unique_string("thrall")
    start_shared(Player, %{player_id: player, zone_id: zone_id})

    {:ok, inst} = InstanceManager.start_instance(zone_id, [player], sandbox_owner: self())

    eventually(fn ->
      record = Repo.get!(PlayerPersistence, player) |> Map.take([:zone_id, :x, :y])
      assert record.zone_id == inst
    end)
  end
end
