defmodule MmoServer.Player do
  use GenServer
  require Logger

  defstruct [:id, :zone_id, :pos, :hp, :mana, :status, :conn_pid]

  @doc """
  Starts a player process registered via `Horde.Registry`.

  Accepts a map containing the `player_id` and `zone_id` so that the
  child can be started with a single argument by `DynamicSupervisor`.
  """
  @spec start_link(map()) :: GenServer.on_start()
  def start_link(%{player_id: player_id, zone_id: zone_id}) do
    name = {:via, Horde.Registry, {PlayerRegistry, player_id}}
    GenServer.start_link(__MODULE__, {player_id, zone_id}, name: name)
  end

  @spec move(term(), {number(), number(), number()}) :: :ok
  def move(player_id, delta) do
    GenServer.cast({:via, Horde.Registry, {PlayerRegistry, player_id}}, {:move, delta})
  end

  @spec get_status(term()) :: :alive | :dead | term()
  def get_status(player_id) do
    GenServer.call({:via, Horde.Registry, {PlayerRegistry, player_id}}, :get_status)
  end

  @spec get_position(term()) :: {number(), number(), number()} | {:error, :not_found}
  def get_position(player_id) do
    GenServer.call({:via, Horde.Registry, {PlayerRegistry, player_id}}, :get_position)
  end

  @impl true
  def init({player_id, zone_id}) do
    state = %__MODULE__{
      id: player_id,
      zone_id: zone_id,
      pos: {0, 0, 0},
      hp: 100,
      mana: 100,
      status: :alive,
      conn_pid: nil
    }
    {:ok, state}
  end

  @impl true
  def handle_cast({:move, {dx, dy, dz}}, state) do
    {x, y, z} = state.pos
    new_pos = {x + dx, y + dy, z + dz}
    MmoServer.Zone.player_moved(state.zone_id, state.id, new_pos)
    Logger.info("Player #{state.id} moved to #{inspect(new_pos)}")
    {:noreply, %{state | pos: new_pos}}
  end

  @impl true
  def handle_cast({:damage, amount}, state) do
    new_hp = max(state.hp - amount, 0)
    state = %{state | hp: new_hp}

    if new_hp <= 0 and state.status == :alive do
      Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.zone_id}", {:death, state.id})
      Process.send_after(self(), :respawn, 10_000)
      {:noreply, %{state | status: :dead}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:respawn, state) do
    new_state = %{state | hp: 100, status: :alive, pos: {0, 0, 0}}
    MmoServer.Zone.player_respawned(state.zone_id, state.id)
    MmoServer.Zone.player_moved(state.zone_id, state.id, new_state.pos)
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.zone_id}", {:player_respawned, state.id})
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_position, _from, state) do
    {:reply, state.pos, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state.status, state}
  end
end
