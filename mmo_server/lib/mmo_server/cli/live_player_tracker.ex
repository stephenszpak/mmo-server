defmodule MmoServer.CLI.LivePlayerTracker do
  @moduledoc """
  Helper utilities for inspecting live player processes.
  """

  @doc """
  Queries all currently active players and prints their positions.
  """
  def print_all_positions do
    players =
      Horde.Registry.select(PlayerRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])

    IO.puts("player_id | x | y | z")

    Enum.each(players, fn id ->
      {x, y, z} = GenServer.call({:via, Horde.Registry, {PlayerRegistry, id}}, :get_position)
      IO.puts("#{id} | #{x} | #{y} | #{z}")
    end)
  end
end
