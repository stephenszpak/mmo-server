defmodule MmoServer.ZoneTest do
  use ExUnit.Case, async: true

  test "zone broadcasts join and leave" do
    {:ok, zone} = MmoServer.Zone.start_link("zone1")
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:zone1")
    GenServer.cast(zone, {:join, "player1"})
    assert_receive {:join, "player1"}
    GenServer.cast(zone, {:leave, "player1"})
    assert_receive {:leave, "player1"}
  end
end
