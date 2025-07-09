defmodule MmoServer.SkillSystem do
  @moduledoc "Skill usage and cooldown tracking"

  require Logger
  alias MmoServer.{Player, SkillEffects, CooldownSystem}

  @spec use_skill(term(), String.t(), term()) :: :ok | {:error, term()}
  def use_skill(player_id, skill_name, target_id) do
    with class_id when is_binary(class_id) <- player_class(player_id),
         {:ok, skill} <- lookup_skill(class_id, skill_name),
         :ok <- CooldownSystem.check_and_set(player_id, skill_name, Map.get(skill, "cooldown", 1)) do
      Logger.info("Player #{player_id} used #{skill_name}")
      SkillEffects.apply_effect(player_id, target_id, skill)
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
    skills()
    |> Enum.find(fn %{"id" => cid} -> cid == class_id end)
    |> case do
      nil -> {:error, :unknown_class}
      class ->
        case Enum.find(class["skills"], fn s -> s["name"] == name end) do
          nil -> {:error, :unknown_skill}
          skill -> {:ok, skill}
        end
    end
  end

  defp skills do
    path = Path.join([:code.priv_dir(:mmo_server), "repo", "class_skills_with_type.json"])
    {:ok, json} = File.read(path)
    {:ok, data} = Jason.decode(json)
    data
  end
end
