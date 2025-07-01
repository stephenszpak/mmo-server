alias MmoServer.{Repo, PlayerRecord}

players = [
  %{player_id: "player1", zone_id: "zone1"},
  %{player_id: "player2", zone_id: "zone1"},
  %{player_id: "player3", zone_id: "zone2"}
]

for attrs <- players do
  %PlayerRecord{}
  |> PlayerRecord.changeset(attrs)
  |> Repo.insert!(on_conflict: :nothing)
end
