defmodule MmoServer.NpcSkillSystem do
  @moduledoc "NPC skill execution and combat integration"

  require Logger
  alias MmoServer.CombatEngine

  @spec use_skill(term(), String.t(), term()) :: :ok
  def use_skill(npc_id, skill_name, target_id) do
    Logger.info("NPC #{npc_id} used #{skill_name}")
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "combat:log", {:npc_used_skill, npc_id, skill_name})
    apply_effect(npc_id, skill_name, target_id)
    :ok
  end

  defp apply_effect(npc_id, _skill_name, target_id) do
    CombatEngine.start_combat({:npc, npc_id}, target_id)
  end
end
