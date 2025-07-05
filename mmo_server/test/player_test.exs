defmodule MmoServer.PlayerTest do
  use ExUnit.Case, async: false

  import MmoServer.TestHelpers

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MmoServer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(MmoServer.Repo, {:shared, self()})
    :ok
  end

  test "player moves and takes damage" do
    zone_id = unique_string("elwynn")
    player_id = unique_string("player")
    start_shared(MmoServer.Zone, zone_id)
    pid = start_shared(MmoServer.Player, %{player_id: player_id, zone_id: zone_id})
    GenServer.cast(pid, {:move, {1, 2, 3}})
    GenServer.cast(pid, {:damage, 10})
    state = :sys.get_state(pid)
    assert state.pos == {1, 2, 3}
    assert state.hp == 90
  end
end
