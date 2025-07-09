defmodule MmoServer.SkillEffectsTest do
  use ExUnit.Case, async: false
  import MmoServer.TestHelpers

  alias MmoServer.{Repo, Class, Skill, SkillSystem, Player}

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MmoServer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(MmoServer.Repo, {:shared, self()})
    :ok
  end

  defp create_class_with_skill(class_id, skill_attrs) do
    Repo.insert!(%Class{id: class_id, name: class_id, role: "dps", lore: ""})
    Repo.insert!(Skill.changeset(%Skill{}, Map.merge(%{class_id: class_id, description: "", cooldown: 1, type: "ranged"}, skill_attrs)))
  end

  test "aoe skill hits all players in radius" do
    zone = unique_string("zone")
    p1 = unique_string("p1")
    p2 = unique_string("p2")
    p3 = unique_string("p3")
    p4 = unique_string("p4")

    create_class_with_skill("mage", %{name: "Blast", effect_type: "aoe", radius: 5})

    start_shared(MmoServer.Zone, zone)
    start_shared(Player, %{player_id: p1, zone_id: zone})
    start_shared(Player, %{player_id: p2, zone_id: zone})
    start_shared(Player, %{player_id: p3, zone_id: zone})
    start_shared(Player, %{player_id: p4, zone_id: zone})

    Player.set_class(p1, "mage")

    GenServer.cast({:via, Horde.Registry, {PlayerRegistry, p2}}, {:move, {1, 1, 0}})
    GenServer.cast({:via, Horde.Registry, {PlayerRegistry, p3}}, {:move, {2, 2, 0}})
    GenServer.cast({:via, Horde.Registry, {PlayerRegistry, p4}}, {:move, {20, 20, 0}})
    :timer.sleep(50)

    SkillSystem.use_skill(p1, "Blast", p2)

    eventually(fn ->
      assert Player.get_hp(p2) == 95
      assert Player.get_hp(p3) == 95
      assert Player.get_hp(p4) == 100
    end)
  end

  test "debuff applied and expires" do
    zone = unique_string("zone")
    a = unique_string("a")
    b = unique_string("b")

    create_class_with_skill("burner", %{name: "Burn", effect_type: "debuff", debuff: %{type: "burn", duration: 2}})

    start_shared(MmoServer.Zone, zone)
    start_shared(Player, %{player_id: a, zone_id: zone})
    start_shared(Player, %{player_id: b, zone_id: zone})

    Player.set_class(a, "burner")

    Phoenix.PubSub.subscribe(MmoServer.PubSub, "combat:log")

    SkillSystem.use_skill(a, "Burn", b)

    assert_receive {:debuff_applied, ^b, _}, 1000

    eventually(fn -> assert Player.get_hp(b) == 99 end)

    eventually(fn -> assert Player.get_hp(b) == 98 end)

    assert_receive {:debuff_removed, ^b, "burn"}, 1500
  end

  test "condition prevents skill" do
    zone = unique_string("zone")
    a = unique_string("a")
    b = unique_string("b")

    create_class_with_skill("cond", %{name: "Strike", condition: "self.hp < 50"})

    start_shared(MmoServer.Zone, zone)
    start_shared(Player, %{player_id: a, zone_id: zone})
    start_shared(Player, %{player_id: b, zone_id: zone})

    Player.set_class(a, "cond")

    SkillSystem.use_skill(a, "Strike", b)

    :timer.sleep(50)
    assert Player.get_hp(b) == 100
  end
end
