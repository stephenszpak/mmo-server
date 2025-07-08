defmodule MmoServer.QuestSystemTest do
  use ExUnit.Case, async: false

  alias MmoServer.{Repo, Player, NPC, LootSystem, Quests, LootDrop}
  import MmoServer.TestHelpers

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    zone_id = unique_string("elwynn")
    start_shared(MmoServer.Zone, zone_id)
    {:ok, zone_id: zone_id}
  end

  test "killing npc updates quest progress", %{zone_id: zone_id} do
    player_id = unique_string("p")
    start_shared(Player, %{player_id: player_id, zone_id: zone_id})
    {:ok, _} = Quests.accept(player_id, Quests.wolf_kill_id())
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:#{zone_id}")

    NPC.damage("wolf_1", 200, player_id)
    assert_receive {:npc_death, "wolf_1"}, 2_000

    eventually(fn ->
      %{progress: [%{"count" => c} | _]} = Quests.get_progress(player_id, Quests.wolf_kill_id())
      assert c == 1
    end)
  end

  test "picking up loot updates quest progress", %{zone_id: zone_id} do
    player_id = unique_string("p")
    start_shared(Player, %{player_id: player_id, zone_id: zone_id})
    {:ok, _} = Quests.accept(player_id, Quests.pelt_collect_id())
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:#{zone_id}")

    NPC.damage("wolf_1", 200)
    assert_receive {:npc_death, "wolf_1"}, 2_000

    drop = eventually(fn ->
      case Repo.all(LootDrop) do
        [d] -> d
        _ -> raise "no loot"
      end
    end, 10, 100)

    {x, y} = NPC.get_position("wolf_1")
    Player.move(player_id, {x, y, 0})
    assert {:ok, _} = LootSystem.pickup(player_id, drop.id)

    eventually(fn ->
      %{progress: [%{"count" => c} | _]} = Quests.get_progress(player_id, Quests.pelt_collect_id())
      assert c == 1
    end)
  end
end
