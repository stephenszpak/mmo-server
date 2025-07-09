defmodule MmoServer.DebuffSystem do
  @moduledoc """
  Manage status debuffs and their expiration.
  """

  use GenServer
  require Logger
  alias MmoServer.CombatEngine

  @tick_ms Application.compile_env(:mmo_server, :debuff_tick_ms, 1_000)

  ## Client API
  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @spec apply_debuff(term(), map()) :: :ok
  def apply_debuff(target_id, debuff) do
    GenServer.cast(__MODULE__, {:apply, target_id, normalize(debuff)})
  end

  ## Server callbacks
  @impl true
  def init(state) do
    schedule_tick()
    {:ok, state}
  end

  @impl true
  def handle_cast({:apply, target, debuff}, state) do
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "combat:log", {:debuff_applied, target, debuff})
    updated = Map.update(state, target, [debuff], fn list -> [debuff | list] end)
    {:noreply, updated}
  end

  @impl true
  def handle_info(:tick, state) do
    state =
      Enum.reduce(state, %{}, fn {entity, debuffs}, acc ->
        {remaining, _} =
          Enum.reduce(debuffs, {[], false}, fn debuff, {list, _} ->
            apply_effect(entity, debuff)
            new = %{debuff | duration: debuff.duration - 1}
            if new.duration > 0 do
              {[new | list], true}
            else
              Phoenix.PubSub.broadcast(MmoServer.PubSub, "combat:log", {:debuff_removed, entity, debuff.type})
              {list, true}
            end
          end)

        if remaining == [] do
          acc
        else
          Map.put(acc, entity, Enum.reverse(remaining))
        end
      end)

    schedule_tick()
    {:noreply, state}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_ms)
  end

  defp apply_effect(entity, %{type: "burn"} = debuff) do
    amount = Map.get(debuff, :damage, 1)
    CombatEngine.damage(entity, amount)
  end

  defp apply_effect(_entity, _debuff), do: :ok

  defp normalize(%{type: type, duration: dur} = debuff) do
    %{type: to_string(type), duration: dur, damage: Map.get(debuff, :damage, 1)}
  end

  defp normalize(map) when is_map(map) do
    map
    |> Enum.into(%{}, fn {k, v} -> {String.to_existing_atom(to_string(k)), v} end)
    |> normalize()
  end
end
