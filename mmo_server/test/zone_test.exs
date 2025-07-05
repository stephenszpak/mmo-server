defmodule MmoServer.ZoneTest do
  use ExUnit.Case, async: true
  import MmoServer.TestHelpers

  test "zone broadcasts join and leave" do
    zone_id = unique_string("zone")
    player_id = unique_string("player")
    {:ok, zone} = MmoServer.Zone.start_link(zone_id)
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:#{zone_id}")
    GenServer.cast(zone, {:join, player_id})
    assert_receive {:join, ^player_id}
    GenServer.cast(zone, {:leave, player_id})
    assert_receive {:leave, ^player_id}
  end
end
