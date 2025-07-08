defmodule MmoServer.WorldStateTest do
  use ExUnit.Case, async: false

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MmoServer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(MmoServer.Repo, {:shared, self()})
    :ok
  end

  test "put and get broadcasts" do
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "world:state")
    :ok = MmoServer.WorldState.put("storm_active", "true")
    assert "true" == MmoServer.WorldState.get("storm_active")
    assert_receive {:world_state_changed, "storm_active", "true"}
  end

  test "delete broadcasts" do
    MmoServer.WorldState.put("open_portal", "true")
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "world:state")
    :ok = MmoServer.WorldState.delete("open_portal")
    assert is_nil(MmoServer.WorldState.get("open_portal"))
    assert_receive {:world_state_deleted, "open_portal"}
  end
end
