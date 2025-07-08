defmodule MmoServer.Zone.NPCConfig do
  @moduledoc """
  Static NPC configuration per zone.
  """

  @npcs %{
    "elwynn" => [
      %{id: "wolf_1", template_id: "wolf", behavior: :patrol, pos: {20, 30}},
      %{id: "wolf_2", template_id: "wolf", behavior: :aggressive, pos: {25, 30}}
    ]
  }

  @spec npcs_for(String.t()) :: list(map())
  def npcs_for(zone_id) do
    Map.get(@npcs, base(zone_id), [])
  end

  defp base(id) do
    id
    |> to_string()
    |> String.split("_", parts: 2)
    |> hd()
  end
end
