defmodule MmoServer.NPC do
  @moduledoc """
  Zone-local non-player character process.
  """
  use GenServer
  require Logger
  alias MmoServer.MobTemplate

  @tick_ms Application.compile_env(:mmo_server, :npc_tick_ms, 1_000)

  defstruct [
    :id,
    :zone_id,
    :type,
    :template,
    :behavior,
    pos: {0, 0},
    hp: 100,
    status: :alive,
    tick_ms: @tick_ms,
    last_attacker: nil
  ]

  @type t :: %__MODULE__{
          id: term(),
          zone_id: term(),
          type: atom(),
          template: MmoServer.MobTemplate.t(),
          behavior: atom(),
          pos: {number(), number()},
          hp: non_neg_integer(),
          status: :alive | :dead,
          tick_ms: non_neg_integer()
        }

  @spec start_link(map()) :: GenServer.on_start()
  def start_link(%{id: id} = args) do
    GenServer.start_link(__MODULE__, args, name: via(id))
  end

  defp via(id), do: {:via, Horde.Registry, {NPCRegistry, {:npc, id}}}

  # Client helpers
  def damage(id, amount, attacker \\ nil), do: GenServer.cast(via(id), {:damage, amount, attacker})
  def get_status(id), do: GenServer.call(via(id), :get_status)
  def get_position(id), do: GenServer.call(via(id), :get_position)
  def get_zone_id(id), do: GenServer.call(via(id), :get_zone_id)

  ## Server callbacks
  @impl true
  def init(args) do
    template = MobTemplate.get!(args.template_id)

    behavior =
      Map.get(args, :behavior) || if(template.aggressive, do: :aggressive, else: :patrol)

    state = %__MODULE__{
      id: args.id,
      zone_id: args.zone_id,
      type: String.to_atom(template.id),
      template: template,
      behavior: behavior,
      pos: Map.get(args, :pos, {0, 0}),
      hp: template.hp,
      tick_ms: Map.get(args, :tick_ms, @tick_ms)
    }

    seed_random(state.id)

    schedule_tick(state.tick_ms)
    {:ok, state}
  end

  @impl true
  def handle_cast({:damage, amount, attacker}, state) do
    if state.status == :alive do
      Phoenix.PubSub.broadcast(
        MmoServer.PubSub,
        "zone:#{state.zone_id}",
        {:npc_damage, state.id, amount}
      )

      new_hp = max(state.hp - amount, 0)
      state = %{state | hp: new_hp, last_attacker: attacker || state.last_attacker}

      if new_hp <= 0 do
        Phoenix.PubSub.broadcast(
          MmoServer.PubSub,
          "zone:#{state.zone_id}",
          {:npc_death, state.id}
        )

        if attacker do
          MmoServer.Player.XP.gain(attacker, state.template.xp_reward)
          MmoServer.Quests.record_event(attacker, %{type: "kill", target: state.template.id})
        end

        MmoServer.LootSystem.drop_for_npc(state)

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
    new_state = %{state | hp: state.template.hp, status: :alive, last_attacker: nil}

    Phoenix.PubSub.broadcast(
      MmoServer.PubSub,
      "zone:#{state.zone_id}",
      {:npc_respawned, state.id}
    )

    :telemetry.execute([:mmo_server, :npc, :respawn], %{count: 1}, %{id: state.id, zone_id: state.zone_id})

    schedule_tick(new_state.tick_ms)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:tick, %{status: :dead} = state) do
    schedule_tick(state.tick_ms)
    {:noreply, state}
  end

  def handle_info(:tick, state) do
    new_state =
      case state.behavior do
        :guard ->
          maybe_aggro(state)

        :aggressive ->
          state
          |> move_towards_player()
          |> maybe_aggro()

        _ ->
          move_random(state)
      end

    schedule_tick(state.tick_ms)
    {:noreply, new_state}
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

    closest =
      players
      |> Enum.map(fn {id, {px, py, _}} -> {id, {px, py}, distance(state.pos, {px, py})} end)
      |> Enum.filter(fn {_id, _pos, dist} -> dist <= 10 end)
      |> Enum.min_by(fn {_id, _pos, dist} -> dist end, fn -> nil end)

    case closest do
      {player_id, _pos, _dist} ->
        MmoServer.CombatEngine.start_combat({:npc, state.id}, player_id)
      _ ->
        :ok
    end

    state
  end

  defp move_towards_player(state) do
    players = MmoServer.Zone.get_position(state.zone_id)

    case Enum.min_by(players, fn {_id, {px, py, _}} -> distance(state.pos, {px, py}) end, fn -> nil end) do
      {_, {px, py, _}} ->
        {x, y} = state.pos
        dx = clamp(px - x)
        dy = clamp(py - y)
        new_pos = {x + dx, y + dy}

        Phoenix.PubSub.broadcast(
          MmoServer.PubSub,
          "zone:#{state.zone_id}",
          {:npc_moved, state.id, new_pos}
        )

        %{state | pos: new_pos}

      _ ->
        move_random(state)
    end
  end

  defp clamp(d) when d > 0, do: 1
  defp clamp(d) when d < 0, do: -1
  defp clamp(_), do: 0

  defp distance({x1, y1}, {x2, y2}) do
    :math.sqrt(:math.pow(x1 - x2, 2) + :math.pow(y1 - y2, 2))
  end
end
