defmodule MmoServer.NpcSkillSystem do
  @moduledoc "NPC skill execution and combat integration"

  require Logger
  alias MmoServer.{CombatEngine, SkillEffects, SkillMetadata}

  @spec use_skill(term(), String.t(), term()) :: :ok
  def use_skill(npc_id, skill_name, target_id) do
    skill = SkillMetadata.get_skill_by_name(skill_name)

    Logger.info("NPC #{npc_id} used #{skill_name}")
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "combat:log", {:npc_used_skill, npc_id, skill_name})
    apply_effect(npc_id, skill, target_id)
    :ok
  end

  defp apply_effect(npc_id, skill, target_id) do
    CombatEngine.start_combat({:npc, npc_id}, target_id)
    SkillEffects.apply_effect({:npc, npc_id}, target_id, skill)
  end
end
