defmodule MmoServer.SkillSystem do
  @moduledoc "Skill usage and cooldown tracking"

  require Logger
  alias MmoServer.{Player, SkillEffects, CooldownSystem, SkillMetadata}

  @spec use_skill(term(), String.t(), term()) :: :ok | {:error, term()}
  def use_skill(player_id, skill_name, target_id) do
    with class_id when is_binary(class_id) <- player_class(player_id),
         {:ok, skill} <- lookup_skill(class_id, skill_name),
         :ok <- CooldownSystem.check_and_set(player_id, skill_name, Map.get(skill, "cooldown_seconds", 1)) do
      Logger.info("Player #{player_id} used #{skill_name}")
      SkillEffects.apply_effect(player_id, target_id, skill)
      :ok
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :unknown_skill}
    end
  end


  defp player_class(player_id) do
    case Player.get_class(player_id) do
      %MmoServer.Class{id: id} -> id
      _ -> nil
    end
  end

  defp lookup_skill(class_id, name) do
    class_skills = SkillMetadata.get_class_skills(class_id)

    case Enum.find(class_skills, fn s -> s["name"] == name end) do
      nil -> {:error, :unknown_skill}
      skill -> {:ok, skill}
    end
  end
end
