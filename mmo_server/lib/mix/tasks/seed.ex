defmodule Mix.Tasks.Seed do
  use Mix.Task

  @shortdoc "Seed the database, zones and players"
  def run(_args) do
    Mix.Task.run("app.start")
    MmoServer.Seeds.run()
  end
end
