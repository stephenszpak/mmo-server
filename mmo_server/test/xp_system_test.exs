defmodule MmoServer.XPSystemTest do
  use ExUnit.Case, async: false

  alias MmoServer.{Repo, Player, PlayerStats, NPC}
  alias MmoServer.Player.XP
  import MmoServer.TestHelpers

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    zone = unique_string("elwynn")
    start_shared(MmoServer.Zone, zone)
    {:ok, zone: zone}
  end

  test "player gains xp when killing npc", %{zone: zone} do
    player = unique_string("p")
    start_shared(Player, %{player_id: player, zone_id: zone})
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:#{zone}")

    NPC.damage("wolf_1", 200, player)
    assert_receive {:npc_death, "wolf_1"}, 2_000

    eventually(fn ->
      stats = Repo.get(PlayerStats, player)
      assert stats.xp == 20
      assert stats.level == 1
    end)
  end

  test "player levels up when xp threshold met", %{zone: zone} do
    player = unique_string("p")
    start_shared(Player, %{player_id: player, zone_id: zone})

    XP.gain(player, 120)

    eventually(fn ->
      stats = Repo.get(PlayerStats, player)
      assert stats.level == 2
      assert stats.xp == 0
      assert stats.next_level_xp > 100
    end)
  end
end

