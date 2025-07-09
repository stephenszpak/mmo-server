defmodule MmoServer.SkillEffects do
  @moduledoc """
  Central engine for applying skill logic.
  """

  alias MmoServer.{CombatEngine, DebuffSystem, Targeting}

  @spec apply_effect(term(), term(), map()) :: :ok
  def apply_effect(user_id, target_id, skill) when is_map(skill) do
    case infer_type(skill) do
      :debuff -> apply_debuff(user_id, target_id, skill)
      :aoe -> apply_aoe(user_id, target_id, skill)
      :condition -> apply_condition(user_id, target_id, skill)
      _ -> apply_direct(user_id, target_id, skill)
    end
  end

  def apply_effect(_user, _target, _), do: :ok

  defp apply_direct(user_id, target_id, skill) do
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

  defp apply_debuff(user_id, target_id, skill) do
    effect = %{type: skill["status_effect"], duration: 2}
    DebuffSystem.apply_debuff(target_id, effect)

    Phoenix.PubSub.broadcast(MmoServer.PubSub, "combat:log", {
      :skill_used,
      user_id,
      skill["name"],
      target_id
    })

    :ok
  end

  defp apply_aoe(user_id, target_id, skill) do
    radius = Map.get(skill, "radius", 3)
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

  defp apply_condition(user_id, target_id, skill) do
    cond = Map.get(skill, "condition", "self.hp < 50")

    if evaluate_condition(user_id, target_id, cond) do
      apply_direct(user_id, target_id, skill)
    else
      :ok
    end
  end

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

  defp infer_type(skill) do
    cond do
      Map.has_key?(skill, "condition") or String.contains?(skill["name"] || "", "Counter") ->
        :condition
      skill["status_effect"] not in [nil, ""] ->
        :debuff
      String.match?(skill["name"] || "", ~r/(Aura|Storm|Wave)/) ->
        :aoe
      true ->
        :direct
    end
  end

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

