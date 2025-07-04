defmodule MmoServer.PlayerTest do
  use ExUnit.Case, async: false

  import MmoServer.TestHelpers

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MmoServer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(MmoServer.Repo, {:shared, self()})
    :ok
  end

  test "player moves and takes damage" do
    start_shared(MmoServer.Zone, "elwynn")
    pid = start_shared(MmoServer.Player, %{player_id: "player1", zone_id: "elwynn"})
    GenServer.cast(pid, {:move, {1, 2, 3}})
    GenServer.cast(pid, {:damage, 10})
    state = :sys.get_state(pid)
    assert state.pos == {1, 2, 3}
    assert state.hp == 90
  end
end
