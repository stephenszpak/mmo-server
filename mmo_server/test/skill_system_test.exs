defmodule MmoServer.SkillSystemTest do
  use ExUnit.Case, async: false
  import MmoServer.TestHelpers

  alias MmoServer.{SkillSystem, Player, NPC}

  setup _tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MmoServer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(MmoServer.Repo, {:shared, self()})
    :ok
  end

  test "skill use broadcasts" do
    zone = unique_string("elwynn")
    a = unique_string("a")

    start_shared(MmoServer.Zone, zone)
    start_shared(Player, %{player_id: a, zone_id: zone})

    Player.set_class(a, "slapstick_monk")

    Phoenix.PubSub.subscribe(MmoServer.PubSub, "combat:log")

    SkillSystem.use_skill(a, "Banana Peel Toss", {:npc, "wolf_1"})

    assert_receive {:skill_used, ^a, "Banana Peel Toss", {:npc, "wolf_1"}}, 1_000
  end

  test "conditional skill fails" do
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

