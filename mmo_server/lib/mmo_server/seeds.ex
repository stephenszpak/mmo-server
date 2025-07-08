defmodule MmoServer.Seeds do
  @moduledoc """
  Consolidated seeding logic for the development database.
  This module can be invoked via `mix seed` or `mix run priv/repo/seeds.exs`.
  """

  alias MmoServer.{
    Repo,
    PlayerPersistence,
    PlayerStats,
    LootDrop,
    MobTemplate,
    Quest
  }

  @zones ["elwynn", "durotar", "zone1"]
  @default_players ["thrall", "jaina", "arthas"]

  @doc """
  Run all seeds. This will ensure zones exist, spawn players, load loot drops
  and populate mob templates and quests.
  """
  def run do
    ensure_zones()
    seed_players()
    seed_loot_drops()
    seed_mob_templates()
    seed_quests()
  end

  defp ensure_zones do
    for zone <- @zones do
      :ok = MmoServer.ZoneManager.ensure_zone_started(zone)
    end
  end

  defp seed_players do
    # default named players seeded into random starter zones
    for player <- @default_players do
      zone = Enum.random(["elwynn", "durotar"])
      create_player(player, zone)
    end

    # numbered test players spawned in zone1
    for id <- 1..5 do
      player_id = "player#{id}"
      create_player(player_id, "zone1")
    end
  end

  defp create_player(player_id, zone) do
    attrs = %{
      id: player_id,
      zone_id: zone,
      x: :rand.uniform() * 100,
      y: :rand.uniform() * 100,
      z: 0.0,
      hp: 100,
      status: "alive"
    }

    %PlayerPersistence{}
    |> PlayerPersistence.changeset(attrs)
    |> Repo.insert!(on_conflict: :replace_all, conflict_target: :id)

    %PlayerStats{}
    |> PlayerStats.changeset(%{player_id: player_id, xp: 0, level: 1, next_level_xp: 100})
    |> Repo.insert!(on_conflict: :replace_all, conflict_target: :player_id)

    Horde.DynamicSupervisor.start_child(
      MmoServer.PlayerSupervisor,
      MmoServer.Player.child_spec(%{player_id: player_id, zone_id: zone})
    )
  end

  defp seed_loot_drops do
    loot_drops = [
      %{npc_id: "wolf_seed1", item: "wolf_pelt", zone_id: "durotar", x: 10.0, y: 5.0, z: 0.0, quality: "common", picked_up: false},
      %{npc_id: "wolf_seed2", item: "wolf_pelt", zone_id: "durotar", x: 12.0, y: 8.0, z: 0.0, quality: "common", picked_up: false},
      %{npc_id: "wolf_seed3", item: "wolf_pelt", zone_id: "elywnn", x: 20.0, y: 15.0, z: 0.0, quality: "common", picked_up: false}
    ]

    for attrs <- loot_drops do
      %LootDrop{}
      |> LootDrop.changeset(attrs)
      |> Repo.insert!(on_conflict: :replace_all, conflict_target: :id)
    end
  end

  defp seed_mob_templates do
    for template <- [
          %{id: "wolf", name: "Wolf", hp: 30, damage: 15, xp_reward: 20, aggressive: true, loot_table: [
            %{item: "wolf_pelt", chance: 1.0, quality: "common"}
          ]},
          %{id: "goblin_scout", name: "Goblin Scout", hp: 20, damage: 10, xp_reward: 10, aggressive: false, loot_table: []},
          %{id: "dungeon_boss", name: "Dungeon Boss", hp: 100, damage: 25, xp_reward: 250, aggressive: true, loot_table: [
            %{item: "legendary_sword", chance: 0.05, quality: "rare"}
          ]}
        ] do
      %MobTemplate{}
      |> MobTemplate.changeset(template)
      |> Repo.insert!(on_conflict: :replace_all, conflict_target: :id)
    end
  end

  defp seed_quests do
    for quest <- [
          %{id: MmoServer.Quests.wolf_kill_id(), title: "Cull the Wolves", description: "Kill 3 wolves", objectives: [%{type: "kill", target: "wolf", count: 3}], rewards: [%{"type" => "xp", "amount" => 100}]},
          %{id: MmoServer.Quests.pelt_collect_id(), title: "Gather Pelts", description: "Collect 2 wolf pelts", objectives: [%{type: "collect", target: "wolf_pelt", count: 2}], rewards: [%{"item" => "wolf_cape"}]}
        ] do
      %Quest{}
      |> Quest.changeset(quest)
      |> Repo.insert!(on_conflict: :replace_all, conflict_target: :id)
    end
  end
end
