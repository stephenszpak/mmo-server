defmodule MmoServer.TestTickInjector do
  @moduledoc """Helpers to manually trigger tick messages in tests."""

  def tick_zone(zone_id) do
    case Horde.Registry.lookup(PlayerRegistry, {:zone, zone_id}) do
      [{pid, _}] -> send(pid, :tick)
      _ -> :ok
    end
  end

  def tick_npc(id) do
    case Horde.Registry.lookup(NPCRegistry, {:npc, id}) do
      [{pid, _}] -> send(pid, :tick)
      _ -> :ok
    end
  end
end
