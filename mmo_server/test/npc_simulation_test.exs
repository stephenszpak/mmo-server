defmodule MmoServer.NPCSimulationTest do
  use ExUnit.Case, async: false

  alias MmoServer.{NPC, Player, ZoneManager}
  import MmoServer.TestHelpers

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MmoServer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(MmoServer.Repo, {:shared, self()})
    ZoneManager.ensure_zone_started("elwynn")
    :ok
  end

  test "npc starts and ticks" do
    start_shared(MmoServer.Zone, "elwynn")

    eventually(fn ->
      assert [{pid, _}] = Horde.Registry.lookup(PlayerRegistry, {:npc, "wolf_1"})
      assert Process.alive?(pid)
    end)

    pos1 = NPC.get_position("wolf_1")
    Process.sleep(1100)
    pos2 = NPC.get_position("wolf_1")
    refute pos1 == pos2
  end

  test "aggressive npc attacks and kills player" do
    start_shared(MmoServer.Zone, "elwynn")
    player = start_shared(Player, %{player_id: "p1", zone_id: "elwynn"})
    Player.move("p1", {25, 30, 0})
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:elwynn")

    eventually(fn ->
      assert :alive == Player.get_status("p1")
      assert NPC.get_status("wolf_2") == :alive
    end)

    assert_receive {:npc_moved, "wolf_2", _}, 1_200
    eventually(fn -> assert Player.get_status("p1") == :dead end, 50, 200)
  end

  test "npc dies and respawns" do
    start_shared(MmoServer.Zone, "elwynn")
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:elwynn")

    eventually(fn -> NPC.get_position("wolf_1") end)
    NPC.damage("wolf_1", 200)

    assert_receive {:npc_death, "wolf_1"}
    status = NPC.get_status("wolf_1")
    assert status == :dead
    pos = NPC.get_position("wolf_1")
    Process.sleep(1100)
    assert pos == NPC.get_position("wolf_1")

    assert_receive {:npc_respawned, "wolf_1"}, 12_000
    assert NPC.get_status("wolf_1") == :alive
  end

  test "npc restarts on crash with single registry entry" do
    start_shared(MmoServer.Zone, "elwynn")

    eventually(fn ->
      assert [{pid, _}] = Horde.Registry.lookup(PlayerRegistry, {:npc, "wolf_1"})
      Process.exit(pid, :kill)
    end)

    eventually(fn ->
      [{pid, _}] = Horde.Registry.lookup(PlayerRegistry, {:npc, "wolf_1"})
      assert Process.alive?(pid)
    end)

    assert 1 == length(Horde.Registry.lookup(PlayerRegistry, {:npc, "wolf_1"}))
  end

  test "zone restart boots npcs" do
    Horde.Registry.lookup(PlayerRegistry, {:zone, "elwynn"})
    |> Enum.each(fn {pid, _} -> Process.exit(pid, :kill) end)

    eventually(fn -> [] == Horde.Registry.lookup(PlayerRegistry, {:zone, "elwynn"}) end)

    start_shared(MmoServer.Zone, "elwynn")
    eventually(fn -> assert NPC.get_status("wolf_1") == :alive end)
  end

  test "aggro triggers only within range" do
    start_shared(MmoServer.Zone, "elwynn")
    start_shared(Player, %{player_id: "p2", zone_id: "elwynn"})
    Player.move("p2", {40, 40, 0})
    :timer.sleep(1100)
    assert Player.get_status("p2") == :alive

    Player.move("p2", {-15, -10, 0})
    eventually(fn -> assert Player.get_status("p2") == :dead end, 50, 200)
  end
end
