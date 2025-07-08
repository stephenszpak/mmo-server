defmodule MmoServer.Player.XP do
  @moduledoc "Player XP and leveling utilities"

  import Ecto.Query
  require Logger
  alias MmoServer.{Repo, PlayerStats}

  @doc """
  Return current xp stats for a player
  """
  def get(player_id) do
    case Repo.get(PlayerStats, player_id) do
      nil -> %{xp: 0, level: 1, next_level_xp: 100}
      stats -> Map.take(stats, [:xp, :level, :next_level_xp])
    end
  end

  @doc """
  Gain XP for a player and handle level up
  """
  def gain(player_id, amount) when is_integer(amount) and amount > 0 do
    Repo.transaction(fn ->
      stats = Repo.get(PlayerStats, player_id) || %PlayerStats{player_id: player_id}

      new_xp = stats.xp + amount
      {level, xp, next_xp} =
        if new_xp >= stats.next_level_xp do
          level_up_values(stats.level + 1, new_xp - stats.next_level_xp)
        else
          {stats.level, new_xp, stats.next_level_xp}
        end

      changes = %{xp: xp, level: level, next_level_xp: next_xp}
      %PlayerStats{stats | xp: xp, level: level, next_level_xp: next_xp}
      |> PlayerStats.changeset(Map.put(changes, :player_id, player_id))
      |> Repo.insert(on_conflict: :replace_all, conflict_target: :player_id)

      if level != stats.level do
        Logger.info("Player #{player_id} leveled up to #{level}")
      else
        Logger.info("Player #{player_id} gained #{amount} XP")
      end

      %{xp: xp, level: level, next_level_xp: next_xp}
    end)
  end

  @doc """
  Force level up for a player
  """
  def level_up(player_id) do
    Repo.transaction(fn ->
      stats = Repo.get(PlayerStats, player_id) || %PlayerStats{player_id: player_id}
      {level, xp, next_xp} = level_up_values(stats.level + 1, 0)

      %PlayerStats{stats | xp: xp, level: level, next_level_xp: next_xp}
      |> PlayerStats.changeset(%{player_id: player_id, xp: xp, level: level, next_level_xp: next_xp})
      |> Repo.insert(on_conflict: :replace_all, conflict_target: :player_id)

      Logger.info("Player #{player_id} leveled up to #{level}")

      %{xp: xp, level: level, next_level_xp: next_xp}
    end)
  end

  defp level_up_values(level, xp \ 0) do
    next_xp = round(100 * :math.pow(1.25, level))
    {level, xp, next_xp}
  end
end

