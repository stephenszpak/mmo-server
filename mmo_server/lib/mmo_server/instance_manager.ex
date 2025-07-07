defmodule MmoServer.InstanceManager do
  @moduledoc """
  Manages dynamic dungeon instances. Each instance runs in its own zone
  and terminates after being idle.
  """

  use GenServer
  alias MmoServer.{Player, ZoneManager}
  alias __MODULE__.Instance

  ## Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, Keyword.merge([name: __MODULE__], opts))
  end

  @doc """
  Start a new instance based on `base_zone_id` and move the given players
  into the new zone. Returns `{:ok, instance_id}`.
  """
  def start_instance(base_zone_id, player_ids) do
    GenServer.call(__MODULE__, {:start_instance, base_zone_id, player_ids})
  end

  @doc """
  Return a list of currently active instance ids.
  """
  def active_instances do
    GenServer.call(__MODULE__, :active_instances)
  end

  ## Server callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:start_instance, base_zone, players}, _from, state) do
    id = unique_id(base_zone)
    stop_zone(base_zone)
    :ok = ZoneManager.ensure_zone_started(id)
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{id}", {:instance_started, id})
    {:ok, pid} = Instance.start_link(id: id, players: players, manager: self())

    Enum.each(players, fn player_id ->
      Player.stop(player_id)
      Horde.DynamicSupervisor.start_child(
        MmoServer.PlayerSupervisor,
        {Player, %{player_id: player_id, zone_id: id}}
      )
    end)

    {:reply, {:ok, id}, Map.put(state, id, pid)}
  end

  def handle_call(:active_instances, _from, state) do
    {:reply, Map.keys(state), state}
  end

  @impl true
  def handle_info({:instance_terminated, id}, state) do
    {:noreply, Map.delete(state, id)}
  end

  ## Helpers

  defp unique_id(base) do
    ts = DateTime.utc_now() |> Calendar.strftime("%Y%m%dT%H%M%S")
    "#{base}_#{ts}"
  end

  def stop_zone(id) do
    Horde.Registry.lookup(PlayerRegistry, {:zone, id})
    |> Enum.each(fn {pid, _} -> GenServer.stop(pid, :shutdown) end)
  end

  # ------------------------------------------------------------------
  defmodule Instance do
    @moduledoc false
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    @impl true
    def init(opts) do
      id = Keyword.fetch!(opts, :id)
      players = MapSet.new(Keyword.get(opts, :players, []))
      manager = Keyword.fetch!(opts, :manager)
      Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:#{id}")
      {:ok, %{id: id, players: players, timer: nil, manager: manager}}
    end

    @impl true
    def handle_info({:join, player_id}, state) do
      state = cancel_timer(state)

      players =
        if player_active_in_zone?(player_id, state.id) do
          MapSet.put(state.players, player_id)
        else
          state.players
        end

      {:noreply, %{state | players: players}}
    end

    def handle_info({:leave, player_id}, state) do
      players = MapSet.delete(state.players, player_id)
      state = %{state | players: players}
      state = maybe_schedule_idle(state)
      {:noreply, state}
    end

    def handle_info(:check_idle, %{players: players} = state) do
      if MapSet.size(players) == 0 do
        Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.id}", {:instance_shutdown, state.id})
        stop_zone(state.id)
        send(state.manager, {:instance_terminated, state.id})
        {:stop, :normal, state}
      else
        {:noreply, state}
      end
    end

    def handle_info(_msg, state), do: {:noreply, state}

    defp maybe_schedule_idle(%{players: players, timer: nil} = state) do
      if MapSet.size(players) == 0 do
        idle_ms = Application.get_env(:mmo_server, :instance_idle_ms, 60_000)
        ref = Process.send_after(self(), :check_idle, idle_ms)
        %{state | timer: ref}
      else
        state
      end
    end

    defp maybe_schedule_idle(state), do: state

    defp cancel_timer(%{timer: nil} = state), do: state

    defp cancel_timer(%{timer: ref} = state) do
      Process.cancel_timer(ref)
      %{state | timer: nil}
    end

    defp player_active_in_zone?(player_id, zone_id) do
      case Horde.Registry.lookup(PlayerRegistry, player_id) do
        [{pid, _}] when Process.alive?(pid) ->
          try do
            case :sys.get_state(pid) do
              %{zone_id: ^zone_id} -> true
              _ -> false
            end
          catch
            _, _ -> false
          end

        _ ->
          false
      end
    end

    defp stop_zone(id), do: MmoServer.InstanceManager.stop_zone(id)
  end
end

