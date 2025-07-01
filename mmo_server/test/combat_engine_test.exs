defmodule MmoServer.CombatEngineTest do
  use MmoServer.DataCase, async: true

  test "zone forwards player position to combat engine" do
    {:ok, engine} = MmoServer.CombatEngine.start_link([])
    {:ok, zone} = MmoServer.Zone.start_link(id: 1)

    send(zone, {:player_moved, 1, {0.0, 0.0, 0.0}})
    assert_receive {:player_position, 1, {0.0, 0.0, 0.0}}

    GenServer.stop(zone)
    GenServer.stop(engine)
  end
end
