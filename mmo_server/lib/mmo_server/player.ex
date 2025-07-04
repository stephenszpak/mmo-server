defmodule MmoServer.Player do
  use GenServer
  require Logger

  defstruct [:id, :zone_id, :pos, :hp, :mana, :status, :conn_pid, :sandbox_owner]

  @doc """
  Starts a player process registered via `Horde.Registry`.

  Accepts a map containing the `player_id` and `zone_id` so that the
  child can be started with a single argument by `DynamicSupervisor`.
  """
  @spec start_link(map()) :: GenServer.on_start()
  def start_link(%{player_id: player_id, zone_id: zone_id} = args) do
    owner = Map.get(args, :sandbox_owner)
    name = {:via, Horde.Registry, {PlayerRegistry, player_id}}
    GenServer.start_link(__MODULE__, {player_id, zone_id, owner}, name: name)
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

  @doc """
  Stops the player process identified by `player_id` if it is running.
  Useful in tests to ensure any replacement processes spawned during zone
  handoff are terminated.
  """
  @spec stop(term()) :: :ok
  def stop(player_id) do
    case Horde.Registry.lookup(PlayerRegistry, player_id) do
      [{pid, _}] ->
        GenServer.stop(pid, :normal)
        :ok
      [] ->
        :ok
    end
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
  alias MmoServer.{Repo, PlayerPersistence, ZoneManager}

  def init({player_id, zone_id, owner_pid}) do
    if owner_pid do
      Ecto.Adapters.SQL.Sandbox.allow(Repo, owner_pid, self())
    end

    persisted =
      Repo.get(PlayerPersistence, player_id,
        caller: owner_pid
      )

    state =
      if persisted do
        %__MODULE__{
          id: persisted.id,
          zone_id: persisted.zone_id,
          pos: {persisted.x, persisted.y, persisted.z},
          hp: persisted.hp,
          mana: 100,
          status: String.to_atom(persisted.status),
          conn_pid: nil,
          sandbox_owner: owner_pid
        }
      else
        %__MODULE__{
          id: player_id,
          zone_id: zone_id,
          pos: {0, 0, 0},
          hp: 100,
          mana: 100,
          status: :alive,
          conn_pid: nil,
          sandbox_owner: owner_pid
        }
      end

    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:#{state.zone_id}")
    MmoServer.Zone.join(state.zone_id, state.id)
    persist_state(state)
    {:ok, state}
  end

  @impl true
  def handle_cast({:move, {dx, dy, dz}}, state) do
    {x, y, z} = state.pos
    new_pos = {x + dx, y + dy, z + dz}
    new_zone = ZoneManager.get_zone_for_position({elem(new_pos, 0), elem(new_pos, 1)}) || state.zone_id

    if new_zone != state.zone_id do
      MmoServer.Zone.leave(state.zone_id, state.id)
      Phoenix.PubSub.unsubscribe(MmoServer.PubSub, "zone:#{state.zone_id}")
      new_state = %{state | pos: new_pos, zone_id: new_zone}
      persist_state(new_state)

      Horde.DynamicSupervisor.start_child(
        MmoServer.PlayerSupervisor,
        {MmoServer.Player,
         %{player_id: state.id, zone_id: new_zone, sandbox_owner: state.sandbox_owner}}
      )

      {:stop, :normal, new_state}
    else
      MmoServer.Zone.player_moved(state.zone_id, state.id, new_pos)
      Logger.info("Player #{state.id} moved to #{inspect(new_pos)}")
      new_state = %{state | pos: new_pos}
      persist_state(new_state)
      {:noreply, new_state}
    end
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
      persist_state(new_state)
      {:noreply, new_state}
    else
      persist_state(state)
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

    persist_state(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:join, _player_id}, state), do: {:noreply, state}

  @impl true
  def handle_info({:leave, _player_id}, state), do: {:noreply, state}

  @impl true
  def handle_info({:player_moved, _player_id, _pos}, state), do: {:noreply, state}

  @impl true
  def handle_info({:player_respawned, _player_id}, state), do: {:noreply, state}

  @impl true
  def handle_info({:death, _player_id}, state), do: {:noreply, state}

  @impl true
  def handle_info({:damage, _player_id, _amount}, state), do: {:noreply, state}

  @impl true
  def handle_info({:positions, _positions}, state), do: {:noreply, state}

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def handle_call(:get_position, _from, state) do
    {:reply, state.pos, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state.status, state}
  end

  @impl true
  def terminate(_reason, state) do
    MmoServer.Zone.leave(state.zone_id, state.id)
    Phoenix.PubSub.unsubscribe(MmoServer.PubSub, "zone:#{state.zone_id}")
    :ok
  end

  defp persist_state(state) do
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

    if is_nil(state.sandbox_owner) or Process.alive?(state.sandbox_owner) do
      %PlayerPersistence{}
      |> PlayerPersistence.changeset(attrs)
      |> Repo.insert(
        on_conflict: :replace_all,
        conflict_target: :id,
        caller: state.sandbox_owner
      )
    end

    :ok
  end
end
