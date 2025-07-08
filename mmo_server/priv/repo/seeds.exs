alias MmoServer.{Repo, MobTemplate}

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
