defmodule Mix.Tasks.Seed do
  @moduledoc "Seeds the database with zones and a test orc."
  use Mix.Task
  alias MmoServer.Zone

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    for id <- 1..2 do
      {:ok, _pid} = Horde.DynamicSupervisor.start_child(MmoServer.ZoneSupervisor, {Zone, id: id})
    end

    IO.puts("Spawned 2 zones")
  end
end
