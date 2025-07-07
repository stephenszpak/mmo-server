alias MmoServer.{Repo, PlayerPersistence, PlayerStats, LootDrop}

players = [
  %{id: "player1", zone_id: "zone1"},
  %{id: "player2", zone_id: "zone1"},
  %{id: "player3", zone_id: "zone2"}
]

for attrs <- players do
  attrs =
    Map.merge(
      %{x: 0.0, y: 0.0, z: 0.0, hp: 100, status: "alive"},
      attrs
    )

  %PlayerPersistence{}
  |> PlayerPersistence.changeset(attrs)
  |> Repo.insert!(on_conflict: :replace_all, conflict_target: :id)

  %PlayerStats{}
  |> PlayerStats.changeset(%{player_id: attrs.id, xp: 0, level: 1, next_level_xp: 100})
  |> Repo.insert!(on_conflict: :replace_all, conflict_target: :player_id)
end

loot_drops = [
  %{npc_id: "wolf_seed1", item: "wolf_pelt", zone_id: "zone1", x: 10.0, y: 5.0, z: 0.0, quality: "common", picked_up: false},
  %{npc_id: "wolf_seed2", item: "wolf_pelt", zone_id: "zone1", x: 12.0, y: 8.0, z: 0.0, quality: "common", picked_up: false},
  %{npc_id: "wolf_seed3", item: "wolf_pelt", zone_id: "zone2", x: 20.0, y: 15.0, z: 0.0, quality: "common", picked_up: false}
]

for attrs <- loot_drops do
  %LootDrop{}
  |> LootDrop.changeset(attrs)
  |> Repo.insert!()
end
