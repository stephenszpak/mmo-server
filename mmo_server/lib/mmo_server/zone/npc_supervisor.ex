defmodule MmoServer.Zone.NPCSupervisor do
  @moduledoc false
  use DynamicSupervisor

  def start_link(zone_id) do
    DynamicSupervisor.start_link(__MODULE__, zone_id)
  end

  @impl true
  def init(_zone_id) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_npc(sup, args) do
    spec = {MmoServer.NPC, args}
    DynamicSupervisor.start_child(sup, spec)
  end
end
