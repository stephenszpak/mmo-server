defmodule MmoServer.Zone do
  use GenServer

  def child_spec(%{zone_id: zone_id} = args) do
    %{
      id: {:zone, zone_id},
      start: {__MODULE__, :start_link, [args]},
      restart: :temporary,
      type: :worker
    }
  end

  def child_spec(zone_id) when is_binary(zone_id), do: child_spec(%{zone_id: zone_id})

  def start_link(%{zone_id: zone_id} = args) do
    GenServer.start_link(__MODULE__, args, name: via(zone_id))
  end

  def start_link(zone_id) when is_binary(zone_id) do
    start_link(%{zone_id: zone_id})
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

  @impl true
  def init(%{zone_id: zone_id} = args) do
    owner = Map.get(args, :sandbox_owner)
    Process.flag(:trap_exit, true)
    {:ok, npc_sup} = MmoServer.Zone.NPCSupervisor.start_link(zone_id)

    MmoServer.Zone.NPCConfig.npcs_for(zone_id)
    |> Enum.each(fn npc ->
      npc = Map.put(npc, :zone_id, zone_id)
      MmoServer.Zone.NPCSupervisor.start_npc(npc_sup, npc)
    end)

    {:ok, _spawn_pid} =
      MmoServer.Zone.SpawnController.start_link(zone_id: zone_id, npc_sup: npc_sup, sandbox_owner: owner)

    schedule_tick()
    send(owner || self(), {:ready, self()})
    {:ok, %{id: zone_id, positions: %{}, npc_sup: npc_sup}}
  end

  @impl true
  def handle_cast({:join, player_id}, state) do
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.id}", {:join, player_id})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:leave, player_id}, state) do
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.id}", {:leave, player_id})
    positions = Map.delete(state.positions, player_id)
    {:noreply, %{state | positions: positions}}
  end

  @impl true
  def handle_cast({:player_moved, player_id, pos}, state) do
    positions = Map.put(state.positions, player_id, pos)

    Phoenix.PubSub.broadcast(
      MmoServer.PubSub,
      "zone:#{state.id}",
      {:player_moved, player_id, pos}
    )

    {:noreply, %{state | positions: positions}}
  end

  @impl true
  def handle_cast({:player_respawned, player_id}, state) do
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.id}", {:player_respawned, player_id})
    {:noreply, state}
  end

  # handle synchronous position fetches
  @impl true
  def handle_call({:get_position, player_id}, _from, state) do
    {:reply, Map.get(state.positions, player_id, {:error, :not_found}), state}
  end

  # return all known positions when no player_id is provided
  # allows callers like the dashboard to fetch the complete table
  @impl true
  def handle_call(:get_position, _from, state) do
    {:reply, state.positions, state}
  end

  @impl true
  def handle_info(:tick, state) do
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.id}", {:positions, state.positions})
    schedule_tick()
    {:noreply, state}
  end

  @impl true
  def handle_info({:EXIT, _pid, _reason}, state) do
    # Child processes such as the NPC supervisor or spawn controller may
    # terminate normally during the tests. Since the zone is not responsible
    # for restarting them, we simply ignore these messages.
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    Horde.Registry.lookup(PlayerRegistry, {:spawn_controller, state.id})
    |> Enum.each(fn {pid, _} -> Process.exit(pid, :shutdown) end)

    if Process.alive?(state.npc_sup) do
      Process.exit(state.npc_sup, :shutdown)
    end

    :ok
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, 100)
  end
end
