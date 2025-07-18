defmodule MmoServer.SpawnControllerTest do
  use ExUnit.Case, async: false

  import MmoServer.TestHelpers

  setup do
    Application.put_env(:mmo_server, :spawn_tick_ms, 50)
    on_exit(fn -> Application.delete_env(:mmo_server, :spawn_tick_ms) end)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MmoServer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(MmoServer.Repo, {:shared, self()})
    zone_id = unique_string("elwynn")
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
    |> Enum.count(fn {_, pid, _, _} ->
      s = :sys.get_state(pid)
      String.starts_with?(to_string(s.id), "wolf_") and s.status == :alive
    end)
  end

  test "controller spawns new NPCs on low population", %{zone_id: zone_id} do

    eventually(fn ->
      assert count_npcs(zone_id) >= 3
    end, 20, 100)
  end

  test "spawned npcs match rule spec", %{zone_id: zone_id} do

    eventually(fn -> assert count_npcs(zone_id) >= 3 end)

    DynamicSupervisor.which_children(npc_sup(zone_id))
    |> Enum.map(fn {_, pid, _, _} -> :sys.get_state(pid) end)
    |> Enum.find(fn s -> s.id not in ["wolf_1", "wolf_2"] end)
    |> then(fn npc ->
      {x, y} = npc.pos
      assert npc.type == :wolf
      assert npc.zone_id == zone_id
      assert x >= 10 and x <= 50
      assert y >= 10 and y <= 50
    end)
  end

  test "controller does not exceed max population", %{zone_id: zone_id} do

    eventually(fn -> assert count_npcs(zone_id) == 5 end)
    Process.sleep(200)
    assert count_npcs(zone_id) == 5
  end

  test "restarting controller does not over-spawn", %{zone_id: zone_id} do

    eventually(fn -> assert count_npcs(zone_id) == 5 end)

    [{pid, _}] = Horde.Registry.lookup(PlayerRegistry, {:spawn_controller, zone_id})
    Process.exit(pid, :kill)
    eventually(fn -> [] == Horde.Registry.lookup(PlayerRegistry, {:spawn_controller, zone_id}) end)
    {:ok, _} = MmoServer.Zone.SpawnController.start_link(zone_id: zone_id, npc_sup: npc_sup(zone_id))
    Process.sleep(100)
    assert count_npcs(zone_id) == 5
  end

  test "dead npcs are replaced", %{zone_id: zone_id} do
    eventually(fn -> assert count_npcs(zone_id) == 5 end)

    MmoServer.NPC.damage("wolf_1", 200)
    eventually(fn -> assert count_npcs(zone_id) == 5 end, 50, 100)
  end
end

