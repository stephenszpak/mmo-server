defmodule MmoServer.SkillSystem do
  @moduledoc "Skill usage and cooldown tracking"

  require Logger
  alias MmoServer.{Player, Class, Skill, Repo, CombatEngine}

  @spec use_skill(String.t(), String.t(), term()) :: :ok | {:error, term()}
  def use_skill(player_id, skill_name, target_id) do
    with %Class{} = class <- Player.get_class(player_id),
         %Skill{} = skill <- Enum.find(class.skills, &(&1.name == skill_name)),
         :ok <- player_use_skill(player_id, skill) do
      Logger.info("Player #{player_id} used #{skill.name} (cooldown: #{skill.cooldown}s)")
      apply_effect(player_id, skill, target_id)
      :ok
    else
      nil -> {:error, :unknown_skill}
      {:error, reason} -> {:error, reason}
    end
  end

  defp player_use_skill(player_id, skill) do
    GenServer.call({:via, Horde.Registry, {PlayerRegistry, player_id}}, {:use_skill, skill})
  catch
    :exit, _ -> {:error, :player_offline}
  end

  defp apply_effect(player_id, %Skill{type: type}, target_id) do
    case type do
      "melee" -> CombatEngine.start_combat(player_id, target_id)
      "ranged" -> CombatEngine.start_combat(player_id, target_id)
      _ -> :ok
    end
  end
end
