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
    Map.get(@rules, base(zone_id), [])
  end

  defp base(id) do
    id
    |> to_string()
    |> String.split("_", parts: 2)
    |> hd()
  end
end
