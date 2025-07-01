defmodule MmoServer.Player do
  use GenServer

  defstruct [:id, :zone_id, :pos, :hp, :mana, :conn_pid]

  def start_link(player_id, zone_id) do
    name = {:via, Horde.Registry, {PlayerRegistry, player_id}}
    GenServer.start_link(__MODULE__, {player_id, zone_id}, name: name)
  end

  def move(player_id, delta) do
    GenServer.cast({:via, Horde.Registry, {PlayerRegistry, player_id}}, {:move, delta})
  end

  def get_position(player_id) do
    GenServer.call({:via, Horde.Registry, {PlayerRegistry, player_id}}, :get_position)
  end

  def init({player_id, zone_id}) do
    state = %__MODULE__{
      id: player_id,
      zone_id: zone_id,
      pos: {0, 0, 0},
      hp: 100,
      mana: 100,
      conn_pid: nil
    }
    {:ok, state}
  end

  def handle_cast({:move, {dx, dy, dz}}, state) do
    {x, y, z} = state.pos
    new_pos = {x + dx, y + dy, z + dz}
    MmoServer.Zone.update_pos(state.zone_id, state.id, new_pos)
    {:noreply, %{state | pos: new_pos}}
  end

  def handle_cast({:damage, amount}, state) do
    {:noreply, %{state | hp: max(state.hp - amount, 0)}}
  end

  def handle_call(:get_position, _from, state) do
    {:reply, state.pos, state}
  end
end
