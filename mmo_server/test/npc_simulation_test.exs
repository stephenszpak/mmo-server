defmodule MmoServer.NPCSimulationTest do
  use ExUnit.Case, async: false

  alias MmoServer.{NPC, Player}
  import MmoServer.TestHelpers

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MmoServer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(MmoServer.Repo, {:shared, self()})
    :ok
  end

  test "npc starts and ticks" do
    start_shared(MmoServer.Zone, "elwynn")

    eventually(fn ->
      assert [{pid, _}] = Horde.Registry.lookup(PlayerRegistry, {:npc, "wolf_1"})
      assert Process.alive?(pid)
    end)

    pos1 = NPC.get_position("wolf_1")
    eventually(fn ->
      assert NPC.get_position("wolf_1") != pos1
    end, 15, 200)
  end

  test "aggressive npc attacks and kills player" do
    start_shared(MmoServer.Zone, "elwynn")
    _player = start_shared(Player, %{player_id: "p1", zone_id: "elwynn"})
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

  test "player can kill npc" do
    start_shared(MmoServer.Zone, "elwynn")
    start_shared(Player, %{player_id: "killer", zone_id: "elwynn"})
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:elwynn")

    MmoServer.CombatEngine.start_combat("killer", {:npc, "wolf_1"})

    assert_receive {:npc_damage, "wolf_1", _}, 5_000
    assert_receive {:npc_death, "wolf_1"}, 5_000
    assert NPC.get_status("wolf_1") == :dead
  end

  test "player enters zone and receives npc updates" do
    start_shared(MmoServer.Zone, "elwynn")
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:elwynn")
    start_shared(Player, %{player_id: "listener", zone_id: "elwynn"})

    assert_receive {:join, "listener"}
    assert_receive {:npc_moved, _, _}, 1_200
  end

  test "player leaves zone mid-combat npc stops" do
    start_shared(MmoServer.Zone, "elwynn")
    start_shared(MmoServer.Zone, "durotar")
    pid = start_shared(Player, %{player_id: "runner", zone_id: "elwynn"})
    Player.move("runner", {25, 30, 0})
    :timer.sleep(1_200)
    hp_before = :sys.get_state(pid).hp
    assert hp_before < 100

    Player.move("runner", {70, 0, 0})
    eventually(fn -> assert {95.0, 30.0, 0.0} == Player.get_position("runner") end)
    Player.move("runner", {10, 0, 0})

    eventually(fn -> assert {105.0, 30.0, 0.0} == Player.get_position("runner") end)
    [{new_pid, _}] = Horde.Registry.lookup(PlayerRegistry, "runner")
    hp_after = :sys.get_state(new_pid).hp
    Process.sleep(600)
    assert hp_after == :sys.get_state(new_pid).hp
  end

  test "aggro detection boundary precision" do
    start_shared(MmoServer.Zone, "elwynn")
    start_shared(Player, %{player_id: "edge", zone_id: "elwynn"})
    Player.move("edge", {35, 30, 0})
    eventually(fn -> assert Player.get_status("edge") == :dead end, 50, 200)

    start_shared(Player, %{player_id: "edge_far", zone_id: "elwynn"})
    Player.move("edge_far", {35.01, 30, 0})
    :timer.sleep(1_200)
    assert Player.get_status("edge_far") == :alive
  end

  test "npc tick loop survives rapid ticks" do
    start_shared(MmoServer.Zone, "elwynn")
    [{pid, _}] = Horde.Registry.lookup(PlayerRegistry, {:npc, "wolf_1"})
    send(pid, :tick)
    send(pid, :tick)
    send(pid, :tick)
    :timer.sleep(200)
    assert Process.alive?(pid)
  end
end
