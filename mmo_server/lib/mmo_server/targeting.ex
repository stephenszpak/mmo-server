defmodule MmoServer.Targeting do
  @moduledoc false

  def entities_within(zone_id, {x, y}, radius) do
    player_targets =
      MmoServer.Zone.get_position(zone_id)
      |> Enum.filter(fn {_id, {px, py, _}} -> distance({x, y}, {px, py}) <= radius end)
      |> Enum.map(fn {id, _} -> id end)

    npc_targets =
      Horde.Registry.select(NPCRegistry, [{{{:npc, :"$1"}, :_, :_}, [], [:"$1"]}])
      |> Enum.filter(fn npc_id ->
        MmoServer.NPC.get_zone_id(npc_id) == zone_id and
          distance({x, y}, MmoServer.NPC.get_position(npc_id)) <= radius
      end)
      |> Enum.map(&{:npc, &1})

    player_targets ++ npc_targets
  end

  defp distance({x1, y1}, {x2, y2}) do
    :math.sqrt(:math.pow(x1 - x2, 2) + :math.pow(y1 - y2, 2))
  end
end

