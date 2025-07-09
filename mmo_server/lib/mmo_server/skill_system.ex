defmodule MmoServer.SkillSystem do
  @moduledoc "Skill usage and cooldown tracking"

  require Logger
  alias MmoServer.{Player, Class, Skill, Repo, CombatEngine, NPC}

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

  defp apply_effect(player_id, %Skill{} = skill, target_id) do
    if skill.condition && !evaluate_condition(player_id, target_id, skill.condition) do
      :ok
    else
      case skill.effect_type do
        "aoe" -> apply_aoe(skill, player_id, target_id)
        "debuff" -> CombatEngine.apply_debuff(target_id, skill.debuff || %{})
        _ ->
          case skill.type do
            "melee" -> CombatEngine.start_combat(player_id, target_id)
            "ranged" -> CombatEngine.start_combat(player_id, target_id)
            _ -> :ok
          end
      end
    end
  end

  defp evaluate_condition(player_id, target_id, expr) do
    cond do
      Regex.match?(~r/^self\.hp\s*<\s*(\d+)/, expr) ->
        [_, val] = Regex.run(~r/^self\.hp\s*<\s*(\d+)/, expr)
        Player.get_hp(player_id) < String.to_integer(val)

      Regex.match?(~r/^target_hp\s*<\s*(\d+)/, expr) ->
        [_, val] = Regex.run(~r/^target_hp\s*<\s*(\d+)/, expr)
        hp_of(target_id) < String.to_integer(val)

      true -> true
    end
  end

  defp hp_of(id) when is_binary(id), do: Player.get_hp(id)
  defp hp_of({:npc, id}), do: MmoServer.NPC.get_hp(id)

  defp apply_aoe(%Skill{radius: radius} = skill, player_id, target_id) do
    zone = zone_of(target_id)
    {tx, ty} = pos2d(target_id)

    players = MmoServer.Zone.get_position(zone)

    Enum.each(players, fn {id, {x, y, _z}} ->
      if distance({tx, ty}, {x, y}) <= radius do
        CombatEngine.damage(id, 5, player_id)
      end
    end)

    Horde.Registry.select(NPCRegistry, [{{{:npc, :"$1"}, :_, :_}, [], [:"$1"]}])
    |> Enum.each(fn npc_id ->
      if MmoServer.NPC.get_zone_id(npc_id) == zone do
        {nx, ny} = MmoServer.NPC.get_position(npc_id)
        if distance({tx, ty}, {nx, ny}) <= radius do
          CombatEngine.damage({:npc, npc_id}, 5, player_id)
        end
      end
    end)

    Phoenix.PubSub.broadcast(MmoServer.PubSub, "combat:log", {:aoe_hit, player_id, skill.name})
  end

  defp zone_of(id) when is_binary(id), do: Player.get_zone_id(id)
  defp zone_of({:npc, id}), do: MmoServer.NPC.get_zone_id(id)

  defp pos2d(id) when is_binary(id) do
    {x, y, _z} = Player.get_position(id)
    {x, y}
  end

  defp pos2d({:npc, id}), do: MmoServer.NPC.get_position(id)

  defp distance({x1, y1}, {x2, y2}) do
    :math.sqrt(:math.pow(x1 - x2, 2) + :math.pow(y1 - y2, 2))
  end
end
