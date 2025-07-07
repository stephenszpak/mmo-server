defmodule MmoServer.ZoneManager do
  @moduledoc """
  Helper utilities for working with zones.
  """

  alias MmoServer.ZoneMap

  @doc """
  Returns the base identifier for a zone. This is useful when zones are started
  with unique suffixes for isolation in tests.
  """
  @spec base(String.t()) :: String.t()
  def base(id) do
    id
    |> to_string()
    |> String.split("_", parts: 2)
    |> hd()
  end

  @spec get_zone_for_position({number(), number()}) :: String.t() | nil
  def get_zone_for_position({x, y}) do
    Enum.find_value(ZoneMap.zones(), fn {id, {{x1, y1}, {x2, y2}}} ->
      if x >= x1 and x < x2 and y >= y1 and y < y2, do: id
    end)
  end

  @doc """
  Ensure a zone process is started under the ZoneSupervisor.
  """
  @spec ensure_zone_started(String.t()) :: :ok | {:error, term()}
  def ensure_zone_started(zone_id) do
    spec = MmoServer.Zone.child_spec(zone_id)

    case Horde.DynamicSupervisor.start_child(MmoServer.ZoneSupervisor, spec) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _}} -> :ok
      {:error, {:already_exists, _}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
