defmodule MmoServer.ZoneHandoffTest do
  use ExUnit.Case, async: false

  alias MmoServer.{Player, PlayerPersistence, Repo, ZoneManager}
  import MmoServer.TestHelpers

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    Repo.delete_all(PlayerPersistence)
    ZoneManager.ensure_zone_started("elwynn")
    ZoneManager.ensure_zone_started("durotar")
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:elwynn")
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:durotar")
    :ok
  end

  test "handoff between zones preserves state and restarts process" do
    player = unique_string("thrall")
    pid = start_shared(Player, %{player_id: player, zone_id: "elwynn"})
    Player.damage(player, 20)

    # capture initial pid from registry
    [{old_pid, _}] = Horde.Registry.lookup(PlayerRegistry, player)
    assert pid == old_pid

    Player.move(player, {95, 0, 0})
    eventually(fn -> assert {95.0, 0.0, 0.0} == Player.get_position(player) end)

    Player.move(player, {10, 0, 0})

    eventually(fn ->
      assert {105.0, 0.0, 0.0} == Player.get_position(player)
      assert "durotar" == Repo.get!(PlayerPersistence, player).zone_id
    end)

    assert_receive {:leave, ^player}
    assert_receive {:join, ^player}

    # new process registration
    [{new_pid, _}] = Horde.Registry.lookup(PlayerRegistry, player)
    refute Process.alive?(old_pid)
    assert Process.alive?(new_pid)
    refute old_pid == new_pid

    state = :sys.get_state(new_pid)
    assert state.zone_id == "durotar"
    assert state.hp == 80
    assert state.status == :alive
    assert state.pos == {105.0, 0.0, 0.0}

    record = Repo.get!(PlayerPersistence, player)
    assert record.hp == 80
    assert record.status == "alive"

    # verify pubsub transition
    :erlang.trace(new_pid, true, [:receive])
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:elwynn", {:ping, :from_a})
    refute_receive {:trace, ^new_pid, :receive, {:ping, :from_a}}, 100

    Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:durotar", {:ping, :from_b})
    assert_receive {:trace, ^new_pid, :receive, {:ping, :from_b}}
    :erlang.trace(new_pid, false, [:receive])

    # restart process and ensure persisted state
    Process.exit(new_pid, :kill)
    eventually(fn -> [] == Horde.Registry.lookup(PlayerRegistry, player) end)

    pid2 = start_shared(Player, %{player_id: player, zone_id: "durotar"})
    state2 = :sys.get_state(pid2)
    assert state2.zone_id == "durotar"
    assert state2.hp == 80
    assert state2.status == :alive
    assert state2.pos == {105.0, 0.0, 0.0}
  end
end
