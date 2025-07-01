defmodule MmoServer.PlayerTest do
  use MmoServer.DataCase, async: true

  test "player login move logout" do
    {:ok, zone} = MmoServer.Zone.start_link(id: 1)
    {:ok, pid} = MmoServer.Player.start_link(id: 1, zone: zone)

    MmoServer.Player.move(pid, {1.0, 2.0, 3.0})
    assert_receive {:player_moved, 1, {1.0, 2.0, 3.0}}

    GenServer.stop(pid)
    GenServer.stop(zone)
  end
end
