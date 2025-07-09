defmodule MmoServer.SkillEffectsTest do
  use ExUnit.Case, async: false
  import MmoServer.TestHelpers

  alias MmoServer.{SkillSystem, Player, NPC}

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MmoServer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(MmoServer.Repo, {:shared, self()})
    :ok
  end

  test "aoe skill hits all nearby npcs" do
    zone = unique_string("elwynn")
    p1 = unique_string("p1")

    start_shared(MmoServer.Zone, zone)
    start_shared(Player, %{player_id: p1, zone_id: zone})

    Player.set_class(p1, "slapstick_monk")

    eventually(fn -> NPC.get_status("wolf_1") == :alive end)

    Phoenix.PubSub.subscribe(MmoServer.PubSub, "combat:log")

    SkillSystem.use_skill(p1, "Banana Peel Toss", {:npc, "wolf_1"})

    assert_receive {:aoe_hit, ^p1, "Banana Peel Toss", targets}, 1000
    assert {:npc, "wolf_1"} in targets

    eventually(fn ->
      assert NPC.get_hp("wolf_1") < 30
      assert NPC.get_hp("wolf_2") < 30
    end)
  end

  test "debuff applied and expires" do
    zone = unique_string("zone")
    a = unique_string("a")
    b = unique_string("b")

    start_shared(MmoServer.Zone, zone)
    start_shared(Player, %{player_id: a, zone_id: zone})
    start_shared(Player, %{player_id: b, zone_id: zone})

    Player.set_class(a, "slapstick_monk")

    Phoenix.PubSub.subscribe(MmoServer.PubSub, "combat:log")

    SkillSystem.use_skill(a, "Rubber Chicken Barrage", b)

    assert_receive {:debuff_applied, ^b, _}, 1000

    eventually(fn -> assert Player.get_hp(b) < 100 end)

    assert_receive {:debuff_removed, ^b, "burn"}, 2_000
  end

  test "condition prevents skill" do
    zone = unique_string("zone")
    a = unique_string("a")
    b = unique_string("b")

    start_shared(MmoServer.Zone, zone)
    start_shared(Player, %{player_id: a, zone_id: zone})
    start_shared(Player, %{player_id: b, zone_id: zone})

    Player.set_class(a, "slapstick_monk")

    SkillSystem.use_skill(a, "Pratfall Counter", b)

    :timer.sleep(50)
    assert Player.get_hp(b) == 100
  end
end
