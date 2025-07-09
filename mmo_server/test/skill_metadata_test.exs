defmodule MmoServer.SkillMetadataTest do
  use ExUnit.Case, async: true

  alias MmoServer.SkillMetadata

  test "class skill lookup" do
    skills = SkillMetadata.get_class_skills("trash_knight")
    assert is_list(skills)
    assert Enum.any?(skills, fn s -> s["name"] == "Scrap Shield Bash" end)
  end

  test "skill by name" do
    skill = SkillMetadata.get_skill_by_name("Scrap Shield Bash")
    assert skill["cooldown_seconds"] == 5
  end

  test "missing class returns empty list" do
    assert SkillMetadata.get_class_skills("unknown") == []
  end

  test "unknown skill returns nil" do
    assert SkillMetadata.get_skill_by_name("nope") == nil
  end
end
