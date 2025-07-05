defmodule MmoServer.Zone.SpawnRules do
  @moduledoc """
  Static spawn definitions for each zone.
  """

  @rules %{
    "elwynn" => [
      %{type: :wolf, min: 3, max: 5, pos_range: {{10, 10}, {50, 50}}}
    ]
  }

  @spec rules_for(String.t()) :: list(map())
  def rules_for(zone_id) do
    Map.get(@rules, zone_id, [])
  end
end
