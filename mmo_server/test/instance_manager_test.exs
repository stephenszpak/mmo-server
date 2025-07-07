defmodule MmoServer.InstanceManagerTest do
  use ExUnit.Case, async: false

  import MmoServer.TestHelpers

  alias MmoServer.{InstanceManager, Player, NPC}

  setup _tags do
    Application.put_env(:mmo_server, :instance_idle_ms, 100)
    on_exit(fn -> Application.delete_env(:mmo_server, :instance_idle_ms) end)

    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MmoServer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(MmoServer.Repo, {:shared, self()})

    zone_id = unique_string("elwynn")

    eventually(fn -> assert [] == InstanceManager.active_instances() end)

    for id <- ["wolf_1", "wolf_2"] do
      Horde.Registry.lookup(NPCRegistry, {:npc, id})
      |> Enum.each(fn {pid, _} -> Process.exit(pid, :kill) end)
    end

    start_shared(MmoServer.Zone, zone_id)
    %{zone_id: zone_id}
  end

  defp npc_sup(zone_id) do
    [{zone_pid, _}] = Horde.Registry.lookup(PlayerRegistry, {:zone, zone_id})
    %{npc_sup: sup} = :sys.get_state(zone_pid)
    sup
  end

  defp count_npcs(zone_id) do
    DynamicSupervisor.which_children(npc_sup(zone_id))
    |> length()
  end

  test "instance creation and player migration", %{zone_id: zone_id} do
    p1 = unique_string("p1")
    p2 = unique_string("p2")

    start_shared(Player, %{player_id: p1, zone_id: zone_id})
    start_shared(Player, %{player_id: p2, zone_id: zone_id})

    {:ok, inst} = InstanceManager.start_instance(zone_id, [p1, p2])

    assert Regex.match?(~r/^#{zone_id}_\d{8}T\d{6}$/, inst)
    assert [inst] == InstanceManager.active_instances()

    eventually(fn ->
      assert Player.get_zone_id(p1) == inst
      assert Player.get_zone_id(p2) == inst
    end)
  end

  test "instance spawns npcs and handles combat", %{zone_id: zone_id} do
    player = unique_string("hero")
    start_shared(Player, %{player_id: player, zone_id: zone_id})

    {:ok, inst} = InstanceManager.start_instance(zone_id, [player])

    eventually(fn ->
      assert count_npcs(inst) >= 2
      assert NPC.get_zone_id("wolf_2") == inst
    end)

    {x, y} = NPC.get_position("wolf_2")
    Player.move(player, {x, y, 0})

    eventually(fn -> assert Player.get_status(player) == :dead end, 50, 200)
  end

  test "instance shuts down when idle", %{zone_id: zone_id} do
    player = unique_string("solo")
    start_shared(Player, %{player_id: player, zone_id: zone_id})

    {:ok, inst} = InstanceManager.start_instance(zone_id, [player])
    Player.stop(player)

    eventually(fn -> assert [] == Horde.Registry.lookup(PlayerRegistry, player) end)

    eventually(fn ->
      assert [] == Horde.Registry.lookup(PlayerRegistry, {:zone, inst})
      assert [] == InstanceManager.active_instances()
    end, 20, 100)

    assert [] == Horde.Registry.lookup(NPCRegistry, {:npc, "wolf_1"})
    assert [] == Horde.Registry.lookup(NPCRegistry, {:npc, "wolf_2"})
  end
end

