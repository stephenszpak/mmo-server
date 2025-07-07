defmodule Mix.Tasks.Seed do
  use Mix.Task
  alias MmoServer.{Repo, PlayerPersistence, PlayerStats, LootDrop}

  @shortdoc "Seed test zones and players"
  def run(_args) do
    Mix.Task.run("app.start")

    for zone <- ["elwynn", "durotar"] do
      :ok = MmoServer.ZoneManager.ensure_zone_started(zone)
    end

    for player <- ["thrall", "jaina", "arthas"] do
      zone = Enum.random(["elwynn", "durotar"])

      attrs = %{
        id: player,
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
      |> PlayerStats.changeset(%{player_id: player, xp: 0, level: 1, next_level_xp: 100})
      |> Repo.insert!(on_conflict: :replace_all, conflict_target: :player_id)

      Horde.DynamicSupervisor.start_child(
        MmoServer.PlayerSupervisor,
        MmoServer.Player.child_spec(%{player_id: player, zone_id: zone})
      )
    end

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
end
