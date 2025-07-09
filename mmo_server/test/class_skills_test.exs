defmodule MmoServer.ClassSkillsTest do
  use ExUnit.Case, async: true
  alias MmoServer.ClassSkills

  test "fetch skills for class" do
    skills = ClassSkills.get_skills_for_class("Trash Knight")
    assert is_list(skills)
    assert Enum.any?(skills, fn s -> s["name"] == "Scrap Shield Bash" end)
  end

  test "fetch single skill" do
    skill = ClassSkills.get_skill("Trash Knight", "Scrap Shield Bash")
    assert skill["cooldown_seconds"] == 5
  end
end
