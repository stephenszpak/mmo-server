defmodule MmoServer.ZoneMap do
  @moduledoc """
  Defines the available zones and their world boundaries.
  """

  @zones %{
    "elwynn" => {{0, 0}, {100, 100}},
    "durotar" => {{100, 0}, {200, 100}}
  }

  @spec zones() :: map()
  def zones, do: @zones
end
