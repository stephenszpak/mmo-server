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
