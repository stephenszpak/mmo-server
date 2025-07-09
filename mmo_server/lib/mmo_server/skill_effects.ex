defmodule MmoServer.SkillEffects do
  @moduledoc """
  Central engine for applying skill logic.
  """

  alias MmoServer.{CombatEngine, DebuffSystem, Targeting}

  @spec apply_effect(term(), term(), map()) :: :ok
  def apply_effect(user_id, target_id, %{"type" => "direct"} = skill) do
    damage = Map.get(skill, "damage", 5)
    CombatEngine.damage(target_id, damage, user_id)

    Phoenix.PubSub.broadcast(MmoServer.PubSub, "combat:log", {
      :skill_used,
      user_id,
      skill["name"],
      target_id
    })

    :ok
  end

  def apply_effect(user_id, target_id, %{"type" => "debuff"} = skill) do
    DebuffSystem.apply_debuff(target_id, Map.get(skill, "debuff", %{}))

    Phoenix.PubSub.broadcast(MmoServer.PubSub, "combat:log", {
      :skill_used,
      user_id,
      skill["name"],
      target_id
    })

    :ok
  end

  def apply_effect(user_id, target_id, %{"type" => "aoe"} = skill) do
    radius = Map.get(skill, "radius", 1)
    zone = zone_of(target_id)
    {x, y} = pos2d(target_id)

    targets = Targeting.entities_within(zone, {x, y}, radius)

    Enum.each(targets, fn id ->
      CombatEngine.damage(id, Map.get(skill, "damage", 5), user_id)
    end)

    Phoenix.PubSub.broadcast(MmoServer.PubSub, "combat:log", {
      :aoe_hit,
      user_id,
      skill["name"],
      targets
    })

    Phoenix.PubSub.broadcast(MmoServer.PubSub, "combat:log", {
      :skill_used,
      user_id,
      skill["name"],
      target_id
    })

    :ok
  end

  def apply_effect(user_id, target_id, %{"type" => "condition"} = skill) do
    if evaluate_condition(user_id, target_id, Map.get(skill, "condition")) do
      inner = Map.put(skill, "type", Map.get(skill, "on_true", "direct"))
      apply_effect(user_id, target_id, inner)
    else
      :ok
    end
  end

  def apply_effect(_user, _target, _), do: :ok

  defp evaluate_condition(player_id, target_id, expr) when is_binary(expr) do
    cond do
      Regex.match?(~r/^self\.hp\s*<\s*(\d+)/, expr) ->
        [_, val] = Regex.run(~r/^self\.hp\s*<\s*(\d+)/, expr)
        MmoServer.Player.get_hp(player_id) < String.to_integer(val)

      Regex.match?(~r/^target_hp\s*<\s*(\d+)/, expr) ->
        [_, val] = Regex.run(~r/^target_hp\s*<\s*(\d+)/, expr)
        hp_of(target_id) < String.to_integer(val)

      true -> true
    end
  end

  defp evaluate_condition(_, _, _), do: true

  defp hp_of(id) when is_binary(id), do: MmoServer.Player.get_hp(id)
  defp hp_of({:npc, id}), do: MmoServer.NPC.get_hp(id)

  defp zone_of(id) when is_binary(id), do: MmoServer.Player.get_zone_id(id)
  defp zone_of({:npc, id}), do: MmoServer.NPC.get_zone_id(id)

  defp pos2d(id) when is_binary(id) do
    {x, y, _z} = MmoServer.Player.get_position(id)
    {x, y}
  end

  defp pos2d({:npc, id}), do: MmoServer.NPC.get_position(id)
end

