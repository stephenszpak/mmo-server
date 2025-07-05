defmodule MmoServer.Zone.SpawnController do
  @moduledoc """
  Periodically ensures that a zone maintains the desired NPC population
  defined by `MmoServer.Zone.SpawnRules`.
  """

  use GenServer
  alias MmoServer.Zone.{SpawnRules, NPCSupervisor}

  @default_tick Application.compile_env(:mmo_server, :spawn_tick_ms, 10_000)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via(opts[:zone_id]))
  end

  def via(zone_id), do: {:via, Horde.Registry, {PlayerRegistry, {:spawn_controller, zone_id}}}

  @impl true
  def init(opts) do
    state = %{
      zone_id: Keyword.fetch!(opts, :zone_id),
      npc_sup: Keyword.fetch!(opts, :npc_sup),
      tick_ms: Keyword.get(opts, :tick_ms, @default_tick),
      last_spawn: %{}
    }

    schedule_tick(state.tick_ms)
    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    state = evaluate_rules(state)
    schedule_tick(state.tick_ms)
    {:noreply, state}
  end

  defp schedule_tick(ms), do: Process.send_after(self(), :tick, ms)

  defp evaluate_rules(state) do
    now = System.system_time(:millisecond)

    Enum.reduce(SpawnRules.rules_for(state.zone_id), state, fn rule, acc ->
      count = npc_count(acc.npc_sup, rule.type)
      need = rule.max - count

      if need > 0 and spawn_allowed?(acc, rule.type, now) do
        spawn_npcs(acc, rule, need, now)
      else
        acc
      end
    end)
  end

  defp spawn_npcs(state, rule, num, timestamp) do
    Enum.each(1..num, fn _ ->
      id = "#{rule.type}_#{System.unique_integer([:positive])}"
      npc = %{id: id, zone_id: state.zone_id, type: rule.type, pos: random_pos(rule.pos_range)}
      NPCSupervisor.start_npc(state.npc_sup, npc)
      Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.zone_id}", {:npc_spawned, id})
    end)

    %{state | last_spawn: Map.put(state.last_spawn, rule.type, timestamp)}
  end

  defp random_pos({{x1, y1}, {x2, y2}}) do
    x = x1 + :rand.uniform(max(x2 - x1, 1)) - 1
    y = y1 + :rand.uniform(max(y2 - y1, 1)) - 1
    {x, y}
  end

  defp npc_count(npc_sup, type) do
    prefix = Atom.to_string(type)

    DynamicSupervisor.which_children(npc_sup)
    |> Enum.count(fn {_, pid, _, _} ->
      s = :sys.get_state(pid)
      alive = Map.get(s, :status) == :alive
      matches = String.starts_with?(to_string(Map.get(s, :id)), prefix) or Map.get(s, :type) == type
      alive and matches
    end)
  end

  defp spawn_allowed?(state, type, now) do
    case Map.get(state.last_spawn, type) do
      nil -> true
      last -> now - last >= state.tick_ms
    end
  end
end
