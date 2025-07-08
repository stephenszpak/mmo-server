defmodule MmoServer.Zone.SpawnController do
  @moduledoc """
  Periodically ensures that a zone maintains the desired NPC population
  defined by `MmoServer.Zone.SpawnRules`.
  """

  use GenServer
  alias MmoServer.Zone.{SpawnRules, NPCSupervisor}

  @doc false
  defp default_tick do
    Application.get_env(:mmo_server, :spawn_tick_ms, 10_000)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via(opts[:zone_id]))
  end

  def via(zone_id), do: {:via, Horde.Registry, {PlayerRegistry, {:spawn_controller, zone_id}}}

  @impl true
  def init(opts) do
    zone_id = Keyword.fetch!(opts, :zone_id)
    Phoenix.PubSub.subscribe(MmoServer.PubSub, "zone:#{zone_id}")

    state = %{
      zone_id: zone_id,
      npc_sup: Keyword.fetch!(opts, :npc_sup),
      tick_ms: Keyword.get(opts, :tick_ms, default_tick()),
      last_spawn: %{}
    }

    state = evaluate_rules(state)
    schedule_tick(state.tick_ms)
    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    state = evaluate_rules(state)
    schedule_tick(state.tick_ms)
    {:noreply, state}
  end

  @impl true
  def handle_info({:npc_death, id}, state) do
    template =
      id
      |> to_string()
      |> String.split("_", parts: 2)
      |> hd()

    state = evaluate_rules(state, [template])
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    # Ignore unrelated zone events such as player or NPC spawns
    {:noreply, state}
  end

  defp schedule_tick(ms), do: Process.send_after(self(), :tick, ms)

  defp evaluate_rules(state, force_types \\ []) do
    now = System.system_time(:millisecond)

    Enum.reduce(SpawnRules.rules_for(state.zone_id), state, fn rule, acc ->
      template = rule.template
      count = npc_count(acc.npc_sup, template)
      need = rule.max - count

      allowed = template in force_types or spawn_allowed?(acc, template, now)

      if need > 0 and allowed do
        spawn_npcs(acc, rule, need, now)
      else
        acc
      end
    end)
  end

  defp spawn_npcs(state, rule, num, timestamp) do
    Enum.each(1..num, fn _ ->
      id = unique_id(rule.template)
      npc = %{id: id, zone_id: state.zone_id, template_id: rule.template, pos: random_pos(rule.pos_range)}
      NPCSupervisor.start_npc(state.npc_sup, npc)
      Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{state.zone_id}", {:npc_spawned, id})
      Logger.info("Spawned #{id} from template #{rule.template}")
    end)

    %{state | last_spawn: Map.put(state.last_spawn, rule.template, timestamp)}
  end

  defp unique_id(template) do
    id = "#{template}_#{System.unique_integer([:positive])}"

    if Horde.Registry.lookup(NPCRegistry, {:npc, id}) == [] do
      id
    else
      unique_id(template)
    end
  end

  defp random_pos({{x1, y1}, {x2, y2}}) do
    x = x1 + :rand.uniform(max(x2 - x1, 1)) - 1
    y = y1 + :rand.uniform(max(y2 - y1, 1)) - 1
    {x, y}
  end

  defp npc_count(npc_sup, template) do
    prefix = to_string(template)

    if Process.alive?(npc_sup) do
      DynamicSupervisor.which_children(npc_sup)
      |> Enum.count(fn {_, pid, _, _} ->
        if Process.alive?(pid) do
          try do
            s = :sys.get_state(pid)
            alive = Map.get(s, :status) == :alive
            matches =
              String.starts_with?(to_string(Map.get(s, :id)), prefix) or
                Map.get(s, :type) == String.to_atom(template)
            alive and matches
          catch
            _, _ ->
              false
          end
        else
          false
        end
      end)
    else
      0
    end
  end

  defp spawn_allowed?(state, template, now) do
    case Map.get(state.last_spawn, template) do
      nil -> true
      last -> now - last >= state.tick_ms
    end
  end
end
