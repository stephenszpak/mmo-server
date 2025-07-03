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

  @spec damage(term(), non_neg_integer()) :: :ok
  def damage(player_id, amount) do
    GenServer.cast({:via, Horde.Registry, {PlayerRegistry, player_id}}, {:damage, amount})
  end

  @spec respawn(term()) :: :ok
  def respawn(player_id) do
    GenServer.cast({:via, Horde.Registry, {PlayerRegistry, player_id}}, :respawn)
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
  alias MmoServer.{Repo, PlayerPersistence}
  alias MmoServer.Player.PersistenceBroadway

  def init({player_id, zone_id}) do
    persisted = Repo.get(PlayerPersistence, player_id)

    state =
      if persisted do
        %__MODULE__{
          id: persisted.id,
          zone_id: persisted.zone_id,
          pos: {persisted.x, persisted.y, persisted.z},
          hp: persisted.hp,
          mana: 100,
          status: String.to_atom(persisted.status),
          conn_pid: nil
        }
      else
        %__MODULE__{
          id: player_id,
          zone_id: zone_id,
          pos: {0, 0, 0},
          hp: 100,
          mana: 100,
          status: :alive,
          conn_pid: nil
        }
      end

    persist(state)
    {:ok, state}
  end

  @impl true
  def handle_cast({:move, {dx, dy, dz}}, state) do
    {x, y, z} = state.pos
    new_pos = {x + dx, y + dy, z + dz}
    MmoServer.Zone.player_moved(state.zone_id, state.id, new_pos)
    Logger.info("Player #{state.id} moved to #{inspect(new_pos)}")
    new_state = %{state | pos: new_pos}
    persist(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:damage, amount}, state) do
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.zone_id}", {:damage, state.id, amount})
    new_hp = max(state.hp - amount, 0)
    state = %{state | hp: new_hp}

    if new_hp <= 0 and state.status == :alive do
      Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.zone_id}", {:death, state.id})
      Process.send_after(self(), :respawn, 10_000)
      new_state = %{state | status: :dead}
      persist(new_state)
      {:noreply, new_state}
    else
      persist(state)
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast(:respawn, state) do
    handle_info(:respawn, state)
  end

  @impl true
  def handle_info(:respawn, state) do
    new_state = %{state | hp: 100, status: :alive, pos: {0, 0, 0}}
    MmoServer.Zone.player_respawned(state.zone_id, state.id)
    MmoServer.Zone.player_moved(state.zone_id, state.id, new_state.pos)

    Phoenix.PubSub.broadcast(
      MmoServer.PubSub,
      "zone:#{state.zone_id}",
      {:player_respawned, state.id}
    )

    persist(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:ack, _ref, _successful, failed}, state) do
    Enum.each(failed, fn
      %Broadway.Message{status: {:error, reason}} ->
        Logger.error("Failed to persist player #{state.id}: #{inspect(reason)}")

      _ ->
        :ok
    end)

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_position, _from, state) do
    {:reply, state.pos, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state.status, state}
  end

  defp persist(state) do
    {x, y, z} = state.pos

    attrs = %{
      id: state.id,
      zone_id: state.zone_id,
      x: x,
      y: y,
      z: z,
      hp: state.hp,
      status: Atom.to_string(state.status)
    }

    PersistenceBroadway.push(attrs)
  end
end
