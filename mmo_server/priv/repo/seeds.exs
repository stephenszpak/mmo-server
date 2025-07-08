alias MmoServer.{Repo, MobTemplate}
alias MmoServer.{Quest}

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

for quest <- [
  %{id: MmoServer.Quests.wolf_kill_id(), title: "Cull the Wolves", description: "Kill 3 wolves", objectives: [ %{type: "kill", target: "wolf", count: 3} ], rewards: [ %{ "type" => "xp", "amount" => 100} ]},
  %{id: MmoServer.Quests.pelt_collect_id(), title: "Gather Pelts", description: "Collect 2 wolf pelts", objectives: [ %{type: "collect", target: "wolf_pelt", count: 2} ], rewards: [ %{ "item" => "wolf_cape"} ]}
] do
  %Quest{}
  |> Quest.changeset(quest)
  |> Repo.insert!(on_conflict: :replace_all, conflict_target: :id)
end
