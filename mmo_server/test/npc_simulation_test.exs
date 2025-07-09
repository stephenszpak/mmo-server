defmodule MmoServer.NPCSimulationTest do
  use ExUnit.Case, async: false

  alias MmoServer.{NPC, Player}
  import MmoServer.TestHelpers

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MmoServer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(MmoServer.Repo, {:shared, self()})
    zone_id = unique_string("elwynn")

    for id <- ["wolf_1", "wolf_2"] do
      Horde.Registry.lookup(NPCRegistry, {:npc, id})
      |> Enum.each(fn {pid, _} -> if Process.alive?(pid), do: Process.exit(pid, :kill) end)
    end

    start_shared(MmoServer.Zone, zone_id)

    eventually(
      fn ->
        assert NPC.get_zone_id("wolf_1") == zone_id
        assert NPC.get_zone_id("wolf_2") == zone_id
        assert NPC.get_status("wolf_1") == :alive
        assert NPC.get_status("wolf_2") == :alive
      end,
      20,
      100
    )

    %{zone_id: zone_id}
  end

  test "npc starts and ticks", %{zone_id: _zone_id} do

    eventually(fn ->
      assert [{pid, _}] = Horde.Registry.lookup(NPCRegistry, {:npc, "wolf_1"})
      assert Process.alive?(pid)
    end)

    pos1 = NPC.get_position("wolf_1")
    eventually(fn ->
      assert NPC.get_position("wolf_1") != pos1
    end, 15, 200)
  end

  test "aggressive npc attacks and kills player", %{zone_id: zone_id} do
    p1 = unique_string("p1")
    _player = start_shared(Player, %{player_id: p1, zone_id: zone_id})
    {nx, ny} = NPC.get_position("wolf_2")
    Player.move(p1, {nx, ny, 0})
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:#{zone_id}")

    eventually(fn ->
      assert :alive == Player.get_status(p1)
      assert NPC.get_status("wolf_2") == :alive
    end)

    assert_receive {:npc_moved, "wolf_2", _}, 2_000
    eventually(fn -> assert Player.get_status(p1) == :dead end, 50, 200)
  end

  test "npc dies and respawns", %{zone_id: zone_id} do
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:#{zone_id}")

    eventually(fn -> NPC.get_position("wolf_1") end)
    NPC.damage("wolf_1", 200)

    assert_receive {:npc_death, "wolf_1"}, 2_000
    status = NPC.get_status("wolf_1")
    assert status == :dead
    pos = NPC.get_position("wolf_1")
    Process.sleep(1100)
    assert pos == NPC.get_position("wolf_1")

    assert_receive {:npc_respawned, "wolf_1"}, 12_000
    assert NPC.get_status("wolf_1") == :alive
  end

  test "npc restarts on crash with single registry entry", _ctx do

    eventually(fn ->
      assert [{pid, _}] = Horde.Registry.lookup(NPCRegistry, {:npc, "wolf_1"})
      Process.exit(pid, :kill)
    end)

    eventually(fn ->
      [{pid, _}] = Horde.Registry.lookup(NPCRegistry, {:npc, "wolf_1"})
      assert Process.alive?(pid)
    end)

    assert 1 == length(Horde.Registry.lookup(NPCRegistry, {:npc, "wolf_1"}))
  end

  test "zone restart boots npcs", %{zone_id: zone_id} do
    Horde.Registry.lookup(PlayerRegistry, {:zone, zone_id})
    |> Enum.each(fn {pid, _} -> Process.exit(pid, :kill) end)

    eventually(fn -> [] == Horde.Registry.lookup(PlayerRegistry, {:zone, zone_id}) end)

    start_shared(MmoServer.Zone, zone_id)
    eventually(fn -> assert NPC.get_status("wolf_1") == :alive end)
  end

  test "aggro triggers only within range", %{zone_id: zone_id} do
    p2 = unique_string("p2")
    start_shared(Player, %{player_id: p2, zone_id: zone_id})
    {nx, ny} = NPC.get_position("wolf_2")
    Player.move(p2, {nx + 15, ny + 10, 0})
    :timer.sleep(1100)
    assert Player.get_status(p2) == :alive

    {nx2, ny2} = NPC.get_position("wolf_2")
    {px, py, _} = Player.get_position(p2)
    Player.move(p2, {nx2 - px, ny2 - py, 0})
    eventually(fn -> assert Player.get_status(p2) == :dead end, 100, 200)
  end

  test "player can kill npc", %{zone_id: zone_id} do
    killer = unique_string("killer")
    start_shared(Player, %{player_id: killer, zone_id: zone_id})
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:#{zone_id}")

    eventually(fn ->
      assert NPC.get_status("wolf_1") == :alive
    end)

    MmoServer.CombatEngine.start_combat(killer, {:npc, "wolf_1"})

    eventually(fn -> assert NPC.get_status("wolf_1") == :dead end, 100, 100)
  end

  test "player enters zone and receives npc updates", %{zone_id: zone_id} do
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:#{zone_id}")
    listener = unique_string("listener")
    start_shared(Player, %{player_id: listener, zone_id: zone_id})

    assert_receive {:join, ^listener}
    assert_receive {:npc_moved, _, _}, 1_200
  end

  test "player leaves zone mid-combat npc stops", %{zone_id: zone_id} do
    start_shared(MmoServer.Zone, "durotar")
    runner = unique_string("runner")
    pid = start_shared(Player, %{player_id: runner, zone_id: zone_id})
    {nx, ny} = NPC.get_position("wolf_2")
    Player.move(runner, {nx, ny, 0})
    :timer.sleep(1_200)
    eventually(fn -> assert :sys.get_state(pid).hp < 100 end, 40, 100)

    Player.move(runner, {70, 0, 0})
    eventually(fn ->
      assert {nx + 70.0, ny, 0.0} == Player.get_position(runner)
    end)
    Player.move(runner, {10, 0, 0})

    eventually(fn ->
      assert {nx + 80.0, ny, 0.0} == Player.get_position(runner)
    end)
    [{new_pid, _}] = Horde.Registry.lookup(PlayerRegistry, runner)
    hp_after = :sys.get_state(new_pid).hp
    Process.sleep(600)
    assert hp_after == :sys.get_state(new_pid).hp
  end

  test "aggro detection boundary precision", %{zone_id: zone_id} do
    edge = unique_string("edge")
    start_shared(Player, %{player_id: edge, zone_id: zone_id})
    {nx, ny} = NPC.get_position("wolf_2")
    Player.move(edge, {nx + 10, ny, 0})
    eventually(fn -> assert Player.get_status(edge) == :dead end, 100, 200)

    far = unique_string("edge_far")
    start_shared(Player, %{player_id: far, zone_id: zone_id})
    {nx2, ny2} = NPC.get_position("wolf_2")
    Player.move(far, {nx2 + 10.01, ny2, 0})
    :timer.sleep(1_200)
    assert Player.get_status(far) == :alive
  end

  test "npc tick loop survives rapid ticks" do
    [{pid, _}] = Horde.Registry.lookup(NPCRegistry, {:npc, "wolf_1"})
    send(pid, :tick)
    send(pid, :tick)
    send(pid, :tick)
    :timer.sleep(200)
    assert Process.alive?(pid)
  end

  test "npc uses skills with cooldown", %{zone_id: zone_id} do
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "combat:log")
    attacker = unique_string("attacker")
    start_shared(Player, %{player_id: attacker, zone_id: zone_id})

    {x, y} = NPC.get_position("wolf_1")
    Player.move(attacker, {x, y, 0})

    assert_receive {:npc_used_skill, "wolf_1", _skill}, 5_000
    refute_receive {:npc_used_skill, "wolf_1", _}, 4_000
  end
end
