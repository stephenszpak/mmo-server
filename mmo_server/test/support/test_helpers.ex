defmodule MmoServer.TestHelpers do
  import ExUnit.Callbacks, only: [start_supervised: 1]

  def start_shared(process_mod, args \\ []) do
    child_spec = Supervisor.child_spec({process_mod, args}, id: {process_mod, make_ref()})
    {:ok, pid} = start_supervised(child_spec)
    Ecto.Adapters.SQL.Sandbox.allow(MmoServer.Repo, self(), pid)
    pid
  end

  def allow_tree(repo, owner, pid) do
    Ecto.Adapters.SQL.Sandbox.allow(repo, owner, pid)

    children =
      try do
        Supervisor.which_children(pid)
      catch
        :exit, _ -> []
      end

    Enum.each(children, fn
      {_, child_pid, _, _} when is_pid(child_pid) ->
        allow_tree(repo, owner, child_pid)
      _ ->
        :ok
    end)
  end
end

