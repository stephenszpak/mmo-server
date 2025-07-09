defmodule MmoServer.BossMetadataTest do
  use ExUnit.Case, async: true

  alias MmoServer.BossMetadata

  test "load all bosses" do
    bosses = BossMetadata.get_all_bosses()
    assert is_list(bosses)
    assert Enum.any?(bosses, fn b -> b["name"] == "Chef Regretulus, the Five-Star Fleshsmith" end)
  end

  test "get boss by name" do
    boss = BossMetadata.get_boss("Chucklegrin, the Final Clown")
    assert boss["description"] =~ "jester"
  end

  test "random boss included in list" do
    assert BossMetadata.random_boss() in BossMetadata.get_all_bosses()
  end
end
