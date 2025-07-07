defmodule Mix.Tasks.Seed do
  use Mix.Task
  alias MmoServer.{Repo, PlayerPersistence}

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

      Horde.DynamicSupervisor.start_child(
        MmoServer.PlayerSupervisor,
        MmoServer.Player.child_spec(%{player_id: player, zone_id: zone})
      )
    end
  end
end
