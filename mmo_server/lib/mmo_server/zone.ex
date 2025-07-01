defmodule MmoServer.Zone do
  @moduledoc """
  A game world zone handling players and NPCs.
  """
  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via(opts[:id]))
  end

  defp via(id), do: {:via, Horde.Registry, {MmoServer.Registry, {:zone, id}}}

  @impl true
  def init(opts) do
    {:ok, %{id: opts[:id], players: %{}}}
  end

  @impl true
  def handle_info({:player_moved, player_id, pos}, state) do
    # broadcast or handle zone logic
    send(MmoServer.CombatEngine, {:player_position, player_id, pos})
    {:noreply, state}
  end
end
