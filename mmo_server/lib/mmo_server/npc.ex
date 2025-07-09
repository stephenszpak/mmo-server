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
    :boss_name,
    phase: 1,
    abilities: [],
    ability_index: 0,
    pos: {0, 0},
    hp: 100,
    status: :alive,
    tick_ms: @tick_ms,
    last_attacker: nil,
    cooldowns: %{}
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
          tick_ms: non_neg_integer(),
          cooldowns: map(),
          boss_name: String.t() | nil,
          phase: pos_integer(),
          abilities: list(),
          ability_index: non_neg_integer()
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
  def get_hp(id), do: GenServer.call(via(id), :get_hp)

  ## Server callbacks
  @impl true
  def init(args) do
    template = MobTemplate.get!(args.template_id)

    type = Map.get(args, :type, String.to_atom(template.id))

    behavior =
      Map.get(args, :behavior) || if(template.aggressive, do: :aggressive, else: :patrol)

    boss_name = Map.get(args, :boss_name)
    abilities =
      if type == :boss and boss_name do
        case MmoServer.BossMetadata.get_boss(boss_name) do
          nil -> []
          boss -> Map.get(boss, "abilities", [])
        end
      else
        []
      end

    state = %__MODULE__{
      id: args.id,
      zone_id: args.zone_id,
      type: type,
      template: template,
      behavior: behavior,
      boss_name: boss_name,
      abilities: abilities,
      ability_index: 0,
      phase: 1,
      pos: Map.get(args, :pos, {0, 0}),
      hp: template.hp,
      tick_ms: Map.get(args, :tick_ms, @tick_ms),
      cooldowns: %{}
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

        if state.type == :boss do
          loot = MmoServer.BossMetadata.roll_loot(state.boss_name)
          Phoenix.PubSub.broadcast(
            MmoServer.PubSub,
            "zone:#{state.zone_id}",
            {:boss_loot, state.id, loot}
          )
        else
          MmoServer.LootSystem.drop_for_npc(state)
        end

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
    new_state = %{state | hp: state.template.hp, status: :alive, last_attacker: nil, phase: 1}

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

  def handle_info(:tick, %{type: :boss} = state) do
    ratio = state.hp / state.template.hp

    new_phase =
      cond do
        ratio > 0.66 -> 1
        ratio > 0.33 -> 2
        true -> 3
      end

    if new_phase > state.phase do
      msg = "Phase #{new_phase}! #{state.boss_name} grows furious!"
      Phoenix.PubSub.broadcast(
        MmoServer.PubSub,
        "zone:#{state.zone_id}",
        {:boss_phase, state.id, new_phase, msg}
      )
    end

    abilities_for_phase =
      state.abilities
      |> Enum.filter(fn ab -> Map.get(ab, "phase", 1) <= new_phase end)
      |> case do
        [] -> state.abilities
        list -> list
      end

    ability = Enum.at(abilities_for_phase, state.ability_index)

    if ability do
      Phoenix.PubSub.broadcast(
        MmoServer.PubSub,
        "combat:log",
        {:boss_ability, state.id, ability["name"], ability["description"], ability["type"]}
      )

      players = Map.keys(MmoServer.Zone.get_position(state.zone_id))

      if players != [] do
        target = Enum.random(players)
        MmoServer.Player.damage(target, 10)
      end
    end

    next = rem(state.ability_index + 1, max(length(abilities_for_phase), 1))
    schedule_tick(state.tick_ms)
    {:noreply, %{state | ability_index: next, phase: new_phase}}
  end

  def handle_info(:tick, state) do
    new_state =
      case state.behavior do
        :guard ->
          state
          |> maybe_aggro()
          |> maybe_use_skill()

        :aggressive ->
          state
          |> move_towards_player()
          |> maybe_aggro()
          |> maybe_use_skill()

        _ ->
          state
          |> move_random()
          |> maybe_use_skill()
      end

    schedule_tick(state.tick_ms)
    {:noreply, new_state}
  end

  def handle_info({:cooldown_ready, skill_name}, state) do
    {:noreply, %{state | cooldowns: Map.delete(state.cooldowns, skill_name)}}
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

  @impl true
  def handle_call(:get_hp, _from, state) do
    {:reply, state.hp, state}
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
        %{state | last_attacker: player_id}
      _ ->
        state
    end
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

  defp maybe_use_skill(%{last_attacker: nil} = state), do: state

  defp maybe_use_skill(state) do
    skills = state.template.skills || []
    ready =
      Enum.filter(skills, fn skill ->
        name = Map.get(skill, :name) || Map.get(skill, "name")
        not Map.has_key?(state.cooldowns, name)
      end)

    if ready == [] do
      state
    else
      name =
        ready
        |> Enum.random()
        |> case do
          %{} = s -> Map.get(s, :name) || Map.get(s, "name")
          other -> other
        end

      skill = MmoServer.SkillMetadata.get_skill_by_name(name)
      cd = Map.get(skill || %{}, "cooldown_seconds", 1)

      MmoServer.NpcSkillSystem.use_skill(state.id, name, state.last_attacker)
      Process.send_after(self(), {:cooldown_ready, name}, cd * 1000)
      %{state | cooldowns: Map.put(state.cooldowns, name, true)}
    end
  end

  defp clamp(d) when d > 0, do: 1
  defp clamp(d) when d < 0, do: -1
  defp clamp(_), do: 0

  defp distance({x1, y1}, {x2, y2}) do
    :math.sqrt(:math.pow(x1 - x2, 2) + :math.pow(y1 - y2, 2))
  end
end
