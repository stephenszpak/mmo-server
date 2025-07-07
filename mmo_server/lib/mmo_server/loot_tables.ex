defmodule MmoServer.LootTables do
  @moduledoc """
  Static loot tables for NPC types.
  """

  @tables %{
    wolf: [
      %{item: "wolf_pelt", quality: "common", chance: 1.0}
    ]
  }

  def drop_quality(_item) do
    roll = :rand.uniform()
    cond do
      roll <= 0.01 -> "epic"
      roll <= 0.10 -> "rare"
      true -> "common"
    end
  end

  @spec loot_for(atom()) :: list(map())
  def loot_for(type) do
    Map.get(@tables, type, [])
  end
end
