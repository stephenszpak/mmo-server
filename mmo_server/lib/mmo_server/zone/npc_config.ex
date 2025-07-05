defmodule MmoServer.Zone.NPCConfig do
  @moduledoc """
  Static NPC configuration per zone.
  """

  @npcs %{
    "elwynn" => [
      %{id: "wolf_1", type: :passive, pos: {20, 30}},
      %{id: "wolf_2", type: :aggressive, pos: {25, 30}}
    ]
  }

  @spec npcs_for(String.t()) :: list(map())
  def npcs_for(zone_id) do
    Map.get(@npcs, zone_id) || Map.get(@npcs, "elwynn", [])
  end
end
