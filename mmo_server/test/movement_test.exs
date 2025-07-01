defmodule MmoServer.MovementTest do
  use ExUnit.Case, async: false

  test "udp movement updates position" do
    {:ok, _zone} = MmoServer.Zone.start_link("zone1")
    {:ok, _p} = MmoServer.Player.start_link(%{player_id: 1, zone_id: "zone1"})

    {:ok, sock} = :gen_udp.open(0, [:binary])

    packet = <<1::32, 1::16, 1.0::float, 2.0::float, 3.0::float>>
    :gen_udp.send(sock, {127,0,0,1}, 4000, packet)
    :timer.sleep(100)

    assert {1.0, 2.0, 3.0} == MmoServer.Player.get_position(1)

    packet2 = <<1::32, 1::16, 10.0::float, 0.0::float, 0.0::float>>
    :gen_udp.send(sock, {127,0,0,1}, 4000, packet2)
    :timer.sleep(100)

    assert {6.0, 2.0, 3.0} == MmoServer.Player.get_position(1)
  end
end
