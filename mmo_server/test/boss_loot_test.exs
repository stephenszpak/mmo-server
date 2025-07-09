defmodule MmoServer.BossLootTest do
  use ExUnit.Case, async: true

  alias MmoServer.BossMetadata

  test "loot generation within ranges" do
    for boss <- BossMetadata.get_all_bosses() do
      name = boss["name"]
      loot = BossMetadata.roll_loot(name)

      assert is_map(loot)
      assert length(loot.epic) >= 1 and length(loot.epic) <= 2
      assert length(loot.rare) >= 1 and length(loot.rare) <= 3

      %{"min" => min, "max" => max} = boss["loot"]["gold_range"]
      assert loot.gold >= min and loot.gold <= max
    end
  end
end
