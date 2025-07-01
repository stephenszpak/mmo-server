defmodule Mix.Tasks.SeedPlayers do
  use Mix.Task

  @shortdoc "Seed test zones and players"
  @moduledoc """
  Starts zone \"zone1\" and spawns a set of test players.

  This task can be run with:

      mix seed_players
  """

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    zone_id = "zone1"
    ensure_zone(zone_id)

    for id <- 1..5 do
      player_id = "player#{id}"
      ensure_player(player_id, zone_id)
    end
  end

  defp ensure_zone(zone_id) do
    spec = {MmoServer.Zone, zone_id}

    case DynamicSupervisor.start_child(MmoServer.ZoneSupervisor, spec) do
      {:ok, pid} ->
        Mix.shell().info("Started zone #{zone_id} (pid #{inspect(pid)})")

      {:error, {:already_started, _pid}} ->
        Mix.shell().info("Zone #{zone_id} already started")

      {:error, {:already_exists, _pid}} ->
        Mix.shell().info("Zone #{zone_id} already exists")

      {:error, reason} ->
        Mix.shell().error("Failed to start zone #{zone_id}: #{inspect(reason)}")
    end
  end

  defp ensure_player(player_id, zone_id) do
    spec = {MmoServer.Player, %{player_id: player_id, zone_id: zone_id}}

    case DynamicSupervisor.start_child(MmoServer.PlayerSupervisor, spec) do
      {:ok, pid} ->
        Mix.shell().info("Started #{player_id} (pid #{inspect(pid)})")

      {:error, {:already_started, _pid}} ->
        Mix.shell().info("#{player_id} already started")

      {:error, {:already_exists, _pid}} ->
        Mix.shell().info("#{player_id} already exists")

      {:error, reason} ->
        Mix.shell().error("Failed to start #{player_id}: #{inspect(reason)}")
    end
  end
end
