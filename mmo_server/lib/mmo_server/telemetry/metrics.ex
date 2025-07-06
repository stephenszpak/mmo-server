defmodule MmoServer.Metrics do
  @moduledoc false
  import Telemetry.Metrics

  def metrics do
    [
      summary("mmo_server.zone.tick.duration", unit: {:native, :millisecond}),
      counter("mmo_server.npc.respawn.count"),
      counter("mmo_server.player.moved.total")
    ]
  end
end
