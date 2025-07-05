defmodule MmoServer.WorldClockTest do
  use ExUnit.Case, async: false

  import MmoServer.TestHelpers

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MmoServer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(MmoServer.Repo, {:shared, self()})
    :ok
  end

  test "clock ticks and broadcasts" do
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "world:clock")
    assert_receive {:tick, _}, 200
  end

  test "world boss event dispatches to zones" do
    start_shared(MmoServer.Zone, "elwynn")
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:elwynn")

    assert_receive {:spawn_world_boss, "elwynn"}, 400
  end

  test "clock restarts if killed" do
    pid = Process.whereis(MmoServer.WorldClock)
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "world:clock")
    Process.exit(pid, :kill)

    eventually(fn ->
      new_pid = Process.whereis(MmoServer.WorldClock)
      assert new_pid != nil and new_pid != pid
    end)

    assert_receive {:tick, _}, 300
  end
end
