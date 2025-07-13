defmodule MmoServer.MovementTest do
  use ExUnit.Case, async: false

  import MmoServer.TestHelpers

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MmoServer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(MmoServer.Repo, {:shared, self()})
    :ok
  end

  test "udp movement updates position" do
    zone = unique_string("zone")
    player = unique_string("player")

    start_shared(MmoServer.Zone, zone)
    start_shared(MmoServer.Player, %{player_id: player, zone_id: zone})

    {:ok, sock} = :gen_udp.open(0, [:binary])

    id_len = byte_size(player)
    packet = <<id_len::8, player::binary, 1::16, 1.0::float-big-32, 2.0::float-big-32, 3.0::float-big-32>>
    :gen_udp.send(sock, {127,0,0,1}, 4000, packet)
    :timer.sleep(100)

    assert {1.0, 2.0, 3.0} == MmoServer.Player.get_position(player)

    packet2 = <<id_len::8, player::binary, 1::16, 10.0::float-big-32, 0.0::float-big-32, 0.0::float-big-32>>
    :gen_udp.send(sock, {127,0,0,1}, 4000, packet2)
    :timer.sleep(100)

    assert {6.0, 2.0, 3.0} == MmoServer.Player.get_position(player)
  end
end
