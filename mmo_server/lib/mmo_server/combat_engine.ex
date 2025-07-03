defmodule MmoServer.CombatEngine do
  @moduledoc """
  Simple real-time combat engine.

  Tracks active combat pairs and periodically deals damage between them.
  """

  use GenServer

  @tick_ms 100
  @damage 5

  ## Client API

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_args) do
    GenServer.start_link(__MODULE__, %MapSet{}, name: __MODULE__)
  end

  @spec start_combat(term(), term()) :: :ok
  def start_combat(attacker_id, target_id) do
    GenServer.cast(__MODULE__, {:start_combat, attacker_id, target_id})
  end

  ## Server callbacks

  @impl true
  def init(set) do
    schedule_tick()
    {:ok, set}
  end

  @impl true
  def handle_cast({:start_combat, attacker, target}, set) do
    {:noreply, MapSet.put(set, {attacker, target})}
  end

  @impl true
  def handle_info(:tick, set) do
    set =
      Enum.reduce(set, set, fn pair = {a, b}, acc ->
        if alive?(a) and alive?(b) do
          deal_damage(a, b)
          acc
        else
          MapSet.delete(acc, pair)
        end
      end)

    schedule_tick()
    {:noreply, set}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_ms)
  end

  defp alive?(player_id) do
    case MmoServer.Player.get_status(player_id) do
      :alive -> true
      _ -> false
    end
  end

  defp deal_damage(a, b) do
    MmoServer.Player.damage(a, @damage)
    MmoServer.Player.damage(b, @damage)
  end
end
