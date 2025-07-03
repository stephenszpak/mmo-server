defmodule MmoServer.Bootstrap do
  @moduledoc """
  Loads persisted players from the database when the application starts.
  """

  use Task, restart: :transient

  alias MmoServer.{Repo, PlayerPersistence}

  def start_link(_arg) do
    Task.start_link(__MODULE__, :run, [])
  end

  @doc false
  def run do
    players = Repo.all(PlayerPersistence)

    players
    |> Enum.map(& &1.zone_id)
    |> Enum.uniq()
    |> Enum.each(fn zone_id ->
      DynamicSupervisor.start_child(MmoServer.ZoneSupervisor, {MmoServer.Zone, zone_id})
    end)

    Enum.each(players, fn player ->
      spec = {MmoServer.Player, %{player_id: player.id, zone_id: player.zone_id}}
      DynamicSupervisor.start_child(MmoServer.PlayerSupervisor, spec)
    end)
  end
end
