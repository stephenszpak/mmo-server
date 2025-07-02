alias MmoServer.{Repo, PlayerPersistence}

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
end
