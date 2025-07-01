defmodule MmoServer.Zone do
  use GenServer

  def start_link(zone_id) do
    GenServer.start_link(__MODULE__, zone_id, name: via(zone_id))
  end

  def join(zone_id, player_id) do
    GenServer.cast(via(zone_id), {:join, player_id})
  end

  def leave(zone_id, player_id) do
    GenServer.cast(via(zone_id), {:leave, player_id})
  end

  def player_moved(zone_id, player_id, pos) do
    GenServer.cast(via(zone_id), {:player_moved, player_id, pos})
  end

  def player_respawned(zone_id, player_id) do
    GenServer.cast(via(zone_id), {:player_respawned, player_id})
  end

  # synchronous API to read a player's current position from the zone
  def get_position(zone_id, player_id) do
    GenServer.call(via(zone_id), {:get_position, player_id})
  end

  def get_position(zone_id) do
    GenServer.call(via(zone_id), :get_position)
  end

  defp via(zone_id), do: {:via, Horde.Registry, {PlayerRegistry, {:zone, zone_id}}}

  def init(zone_id) do
    schedule_tick()
    {:ok, %{id: zone_id, positions: %{}}}
  end

  def handle_cast({:join, player_id}, state) do
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.id}", {:join, player_id})
    {:noreply, state}
  end

  def handle_cast({:leave, player_id}, state) do
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.id}", {:leave, player_id})
    positions = Map.delete(state.positions, player_id)
    {:noreply, %{state | positions: positions}}
  end

  def handle_cast({:player_moved, player_id, pos}, state) do
    positions = Map.put(state.positions, player_id, pos)
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.id}", {:player_moved, player_id, pos})
    {:noreply, %{state | positions: positions}}
  end

  def handle_cast({:player_respawned, player_id}, state) do
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.id}", {:player_respawned, player_id})
    {:noreply, state}
  end

  # handle synchronous position fetches
  def handle_call({:get_position, player_id}, _from, state) do
    {:reply, Map.get(state.positions, player_id, {:error, :not_found}), state}
  end


  # return all known positions when no player_id is provided
  # allows callers like the dashboard to fetch the complete table
  def handle_call(:get_position, _from, state) do
    {:reply, state.positions, state}
  end

  def handle_info(:tick, state) do
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.id}", {:positions, state.positions})
    schedule_tick()
    {:noreply, state}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, 100)
  end
end
