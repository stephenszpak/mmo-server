defmodule MmoServer.Player do
  use GenServer

  def start_link(player_id, zone_id) do
    name = {:via, Horde.Registry, {PlayerRegistry, player_id}}
    GenServer.start_link(__MODULE__, {player_id, zone_id}, name: name)
  end

  def init({player_id, zone_id}) do
    state = %{id: player_id, zone: zone_id, position: {0, 0, 0}, hp: 100}
    {:ok, state}
  end

  def handle_cast({:move, {dx, dy, dz}}, state) do
    {x, y, z} = state.position
    new_pos = {x + dx, y + dy, z + dz}
    {:noreply, %{state | position: new_pos}}
  end

  def handle_cast({:damage, amount}, state) do
    {:noreply, %{state | hp: max(state.hp - amount, 0)}}
  end
end
