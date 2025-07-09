defmodule MmoServer.DebuffSystemTest do
  use ExUnit.Case, async: false
  import MmoServer.TestHelpers

  alias MmoServer.{DebuffSystem, Player}

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MmoServer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(MmoServer.Repo, {:shared, self()})
    :ok
  end

  test "burn debuff ticks and expires" do
    zone = unique_string("zone")
    a = unique_string("a")

    start_shared(MmoServer.Zone, zone)
    start_shared(Player, %{player_id: a, zone_id: zone})

    Phoenix.PubSub.subscribe(MmoServer.PubSub, "combat:log")

    DebuffSystem.apply_debuff(a, %{type: "burn", duration: 2, damage: 1})

    assert_receive {:debuff_applied, ^a, _}, 1_000

    eventually(fn -> assert Player.get_hp(a) == 99 end)
    eventually(fn -> assert Player.get_hp(a) == 98 end)

    assert_receive {:debuff_removed, ^a, "burn"}, 2_000
  end
end

