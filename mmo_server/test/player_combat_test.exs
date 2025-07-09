defmodule MmoServer.PlayerCombatTest do
  use ExUnit.Case, async: false
  import MmoServer.TestHelpers

  alias MmoServer.{Player, NPC}

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MmoServer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(MmoServer.Repo, {:shared, self()})
    :ok
  end

  test "cooldown enforcement" do
    zone = unique_string("elwynn")
    player = unique_string("p")

    start_shared(MmoServer.Zone, zone)
    start_shared(Player, %{player_id: player, zone_id: zone})

    Player.set_class(player, "trash_knight")
    eventually(fn -> NPC.get_status("wolf_1") == :alive end)
    Player.set_target(player, {:npc, "wolf_1"})

    assert {:ok, _dmg} = Player.cast_skill(player, "Scrap Shield Bash")
    assert {:error, :cooldown} = Player.cast_skill(player, "Scrap Shield Bash")
  end

  test "tab target skill casting" do
    zone = unique_string("elwynn")
    player = unique_string("p")

    start_shared(MmoServer.Zone, zone)
    start_shared(Player, %{player_id: player, zone_id: zone})

    Player.set_class(player, "trash_knight")
    eventually(fn -> NPC.get_status("wolf_1") == :alive end)
    Player.set_target(player, {:npc, "wolf_1"})

    hp1 = NPC.get_hp("wolf_1")
    hp2 = NPC.get_hp("wolf_2")

    assert {:ok, _} = Player.cast_skill(player, "Scrap Shield Bash")

    eventually(fn -> assert NPC.get_hp("wolf_1") < hp1 end)
    assert NPC.get_hp("wolf_2") == hp2
  end

  test "damage calculation uses metadata" do
    zone = unique_string("elwynn")
    player = unique_string("p")

    start_shared(MmoServer.Zone, zone)
    start_shared(Player, %{player_id: player, zone_id: zone})

    Player.set_class(player, "trash_knight")
    eventually(fn -> NPC.get_status("wolf_1") == :alive end)
    Player.set_target(player, {:npc, "wolf_1"})

    {:ok, damage} = Player.cast_skill(player, "Scrap Shield Bash")
    expected = 69 + round(10 * 0.43)
    assert damage == expected
  end
end
