defmodule MmoServer.TestHelpers do
  import ExUnit.Callbacks, only: [start_supervised: 1]

  def start_shared(process_mod, args \\ []) do
    child_spec = Supervisor.child_spec({process_mod, args}, id: {process_mod, make_ref()})
    {:ok, pid} = start_supervised(child_spec)
    Ecto.Adapters.SQL.Sandbox.allow(MmoServer.Repo, self(), pid)
    pid
  end
end

