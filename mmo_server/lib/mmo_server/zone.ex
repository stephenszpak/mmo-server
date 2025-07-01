defmodule MmoServer.Zone do
  use GenServer

  def start_link(zone_id) do
    GenServer.start_link(__MODULE__, zone_id, name: via(zone_id))
  end

  defp via(zone_id), do: {:via, Horde.Registry, {PlayerRegistry, {:zone, zone_id}}}

  def init(zone_id) do
    {:ok, %{id: zone_id, players: []}}
  end

  def handle_cast({:join, player_id}, state) do
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.id}", {:join, player_id})
    {:noreply, %{state | players: [player_id | state.players]}}
  end

  def handle_cast({:leave, player_id}, state) do
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.id}", {:leave, player_id})
    {:noreply, %{state | players: List.delete(state.players, player_id)}}
  end
end
