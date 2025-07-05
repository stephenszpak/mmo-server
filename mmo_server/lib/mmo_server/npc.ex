defmodule MmoServer.NPC do
  @moduledoc """
  Zone-local non-player character process.
  """
  use GenServer
  require Logger

  @tick_ms Application.compile_env(:mmo_server, :npc_tick_ms, 1_000)

  defstruct [
    :id,
    :zone_id,
    :type,
    pos: {0, 0},
    hp: 100,
    status: :alive,
    tick_ms: @tick_ms
  ]

  @type t :: %__MODULE__{
          id: term(),
          zone_id: term(),
          type: atom(),
          pos: {number(), number()},
          hp: non_neg_integer(),
          status: :alive | :dead,
          tick_ms: non_neg_integer()
        }

  @spec start_link(map()) :: GenServer.on_start()
  def start_link(%{id: id} = args) do
    GenServer.start_link(__MODULE__, args, name: via(id))
  end

  defp via(id), do: {:via, Horde.Registry, {PlayerRegistry, {:npc, id}}}

  # Client helpers
  def damage(id, amount), do: GenServer.cast(via(id), {:damage, amount})
  def get_status(id), do: GenServer.call(via(id), :get_status)
  def get_position(id), do: GenServer.call(via(id), :get_position)
  def get_zone_id(id), do: GenServer.call(via(id), :get_zone_id)

  ## Server callbacks
  @impl true
  def init(args) do
    state = %__MODULE__{
      id: args.id,
      zone_id: args.zone_id,
      type: Map.get(args, :type, :passive),
      pos: Map.get(args, :pos, {0, 0}),
      tick_ms: Map.get(args, :tick_ms, @tick_ms)
    }

    seed_random(state.id)

    schedule_tick(state.tick_ms)
    {:ok, state}
  end

  @impl true
  def handle_cast({:damage, amount}, state) do
    if state.status == :alive do
      Phoenix.PubSub.broadcast(
        MmoServer.PubSub,
        "zone:#{state.zone_id}",
        {:npc_damage, state.id, amount}
      )

      new_hp = max(state.hp - amount, 0)
      state = %{state | hp: new_hp}

      if new_hp <= 0 do
        Phoenix.PubSub.broadcast(
          MmoServer.PubSub,
          "zone:#{state.zone_id}",
          {:npc_death, state.id}
        )

        Process.send_after(self(), :respawn, 10_000)
        {:noreply, %{state | status: :dead}}
      else
        {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:respawn, state) do
    new_state = %{state | hp: 100, status: :alive}

    Phoenix.PubSub.broadcast(
      MmoServer.PubSub,
      "zone:#{state.zone_id}",
      {:npc_respawned, state.id}
    )

    schedule_tick(new_state.tick_ms)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:tick, %{status: :dead} = state) do
    schedule_tick(state.tick_ms)
    {:noreply, state}
  end

  def handle_info(:tick, state) do
    state =
      case state.type do
        :passive ->
          move_random(state)

        :aggressive ->
          maybe_aggro(state)
          |> move_random()

        _other ->
          move_random(state)
      end

    schedule_tick(state.tick_ms)
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state.status, state}
  end

  def handle_call(:get_position, _from, state) do
    {:reply, state.pos, state}
  end

  def handle_call(:get_zone_id, _from, state) do
    {:reply, state.zone_id, state}
  end

  defp schedule_tick(ms), do: Process.send_after(self(), :tick, ms)

  defp move_random(state) do
    {x, y} = state.pos
    dx = :rand.uniform(3) - 2
    dy = :rand.uniform(3) - 2
    new_pos = {x + dx, y + dy}

    Phoenix.PubSub.broadcast(
      MmoServer.PubSub,
      "zone:#{state.zone_id}",
      {:npc_moved, state.id, new_pos}
    )

    %{state | pos: new_pos}
  end

  defp seed_random(id) do
    <<a, b, c, _rest::binary>> = :crypto.hash(:md5, to_string(id))
    :rand.seed(:exsplus, {a, b, c})
  end

  defp maybe_aggro(state) do
    players = MmoServer.Zone.get_position(state.zone_id)

    Enum.find(players, fn {_id, {px, py, _}} ->
      distance(state.pos, {px, py}) <= 10
    end)
    |> case do
      {player_id, _} -> MmoServer.CombatEngine.start_combat({:npc, state.id}, player_id)
      _ -> :ok
    end

    state
  end

  defp distance({x1, y1}, {x2, y2}) do
    :math.sqrt(:math.pow(x1 - x2, 2) + :math.pow(y1 - y2, 2))
  end
end
