defmodule MmoServer.PlayerTest do
  use ExUnit.Case, async: true

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MmoServer.Repo)
  end

  test "player moves and takes damage" do
    {:ok, pid} = MmoServer.Player.start_link(%{player_id: "player1", zone_id: "zone1"})
    GenServer.cast(pid, {:move, {1, 2, 3}})
    GenServer.cast(pid, {:damage, 10})
    state = :sys.get_state(pid)
    assert state.pos == {1, 2, 3}
    assert state.hp == 90
  end
end
