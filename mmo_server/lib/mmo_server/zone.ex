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

  def update_pos(zone_id, player_id, pos) do
    GenServer.cast(via(zone_id), {:update_pos, player_id, pos})
  end

  # synchronous API to read a player's current position from the zone
  def get_position(zone_id, player_id) do
    GenServer.call(via(zone_id), {:get_position, player_id})
  end

  # fetch all known positions for a zone
  def get_position(zone_id) do
    GenServer.call(via(zone_id), :get_position)
  end

  defp via(zone_id), do: {:via, Horde.Registry, {PlayerRegistry, {:zone, zone_id}}}

  def init(zone_id) do
    table = table_name(zone_id)
    :ets.new(table, [:named_table, :public, :set])
    schedule_tick()
    {:ok, %{id: zone_id, table: table}}
  end

  def handle_cast({:join, player_id}, state) do
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.id}", {:join, player_id})
    {:noreply, state}
  end

  def handle_cast({:leave, player_id}, state) do
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.id}", {:leave, player_id})
    :ets.delete(state.table, player_id)
    {:noreply, state}
  end

  def handle_cast({:update_pos, player_id, pos}, state) do
    :ets.insert(state.table, {player_id, pos})
    {:noreply, state}
  end

  # handle synchronous position fetches
  def handle_call({:get_position, player_id}, _from, state) do
    reply =
      case :ets.lookup(state.table, player_id) do
        [{^player_id, pos}] -> pos
        [] -> {:error, :not_found}
      end

    {:reply, reply, state}
  end

  # return all known positions when no player_id is provided
  # allows callers like the dashboard to fetch the complete table
  def handle_call(:get_position, _from, state) do
    {:reply, :ets.tab2list(state.table), state}
  end

  def handle_info(:tick, state) do
    positions = :ets.tab2list(state.table)
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.id}", {:positions, positions})
    schedule_tick()
    {:noreply, state}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, 100)
  end

  def table_name(zone_id), do: String.to_atom("zone_pos_" <> to_string(zone_id))
end
