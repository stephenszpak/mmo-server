defmodule MmoServer.Bootstrap do
  @moduledoc """
  Loads persisted players from the database when the application starts.
  """

  use Task, restart: :transient

  alias MmoServer.{Repo, PlayerPersistence, ZoneManager}

  def start_link(_arg) do
    Task.start_link(__MODULE__, :run, [])
  end

  @doc false
  def run do
    players = Repo.all(PlayerPersistence)

    players
    |> Enum.map(& &1.zone_id)
    |> Enum.uniq()
    |> Enum.each(&ZoneManager.ensure_zone_started/1)

    Enum.each(players, fn player ->
      spec = {MmoServer.Player, %{player_id: player.id, zone_id: player.zone_id}}
      Horde.DynamicSupervisor.start_child(MmoServer.PlayerSupervisor, spec)
    end)
  end
end
