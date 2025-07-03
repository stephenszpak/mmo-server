defmodule MmoServer.TestHelpers do
  def start_shared(process_mod, args \\ []) do
    {:ok, pid} = start_supervised({process_mod, args})
    Ecto.Adapters.SQL.Sandbox.allow(MmoServer.Repo, self(), pid)
    pid
  end
end

