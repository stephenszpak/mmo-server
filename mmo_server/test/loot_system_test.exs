defmodule MmoServer.LootSystemTest do
  use ExUnit.Case, async: false

  alias MmoServer.{LootSystem, LootDrop, NPC, Player, Repo}
  alias MmoServer.Player.Inventory
  import MmoServer.TestHelpers

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    zone_id = unique_string("elwynn")
    start_shared(MmoServer.Zone, zone_id, sandbox_owner: self())
    {:ok, zone_id: zone_id}
  end

  test "loot is dropped when npc dies", %{zone_id: zone_id} do
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:#{zone_id}")
    NPC.damage("wolf_1", 200)
    assert_receive {:npc_death, "wolf_1"}, 2000
    eventually(fn -> assert [%LootDrop{}] = Repo.all(LootDrop) end, 10, 100)
  end

  test "player can pick up loot", %{zone_id: zone_id} do
    player_id = unique_string("p")
    start_shared(Player, %{player_id: player_id, zone_id: zone_id}, sandbox_owner: self())
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:#{zone_id}")
    NPC.damage("wolf_1", 200)

    drop =
      eventually(fn ->
        case Repo.all(LootDrop) do
          [d] -> d
          _ -> raise "no loot"
        end
      end, 10, 100)

    {x, y} = NPC.get_position("wolf_1")
    Player.move(player_id, {x, y, 0})

    assert {:ok, _} = LootSystem.pickup(player_id, drop.id)

    eventually(fn ->
      assert Repo.get(LootDrop, drop.id).picked_up
    end)

    eventually(fn ->
      [item] = Inventory.list(player_id)
      assert item.item == drop.item
      assert item.quality == drop.quality
    end)

    assert_receive {:loot_picked_up, ^player_id, _}, 1000
  end
end
