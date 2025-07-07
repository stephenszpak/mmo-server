defmodule MmoServer.LootTables do
  @moduledoc """
  Static loot tables for NPC types.
  """

  @tables %{
    wolf: [%{item: "wolf_pelt", chance: 0.5}]
  }

  @spec loot_for(atom()) :: list(map())
  def loot_for(type) do
    Map.get(@tables, type, [])
  end
end
