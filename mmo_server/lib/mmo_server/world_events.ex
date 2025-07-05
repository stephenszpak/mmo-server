defmodule MmoServer.WorldEvents do
  @moduledoc """
  Dispatches world-level events to players and zones.
  """

  alias MmoServer.{PubSub, ZoneMap}

  @spec spawn_world_boss() :: :ok
  def spawn_world_boss do
    for zone_id <- Map.keys(ZoneMap.zones()) do
      Phoenix.PubSub.broadcast(PubSub, "zone:#{zone_id}", {:spawn_world_boss, zone_id})
    end

    :ok
  end

  @spec rotate_merchant_inventory() :: :ok
  def rotate_merchant_inventory do
    Phoenix.PubSub.broadcast(PubSub, "world:clock", :rotate_merchant_inventory)
    :ok
  end

  @spec storm_event() :: :ok
  def storm_event do
    Phoenix.PubSub.broadcast(PubSub, "world:clock", :storm)
    :ok
  end
end
