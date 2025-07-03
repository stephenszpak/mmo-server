defmodule MmoServer.TestHelpers do
  import ExUnit.Callbacks, only: [start_supervised: 1]

  def start_shared(process_mod, args \\ []) do
    child_spec = Supervisor.child_spec({process_mod, args}, id: {process_mod, make_ref()})
    {:ok, pid} = start_supervised(child_spec)
    allow_tree(MmoServer.Repo, self(), pid)
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

  def eventually(fun, attempts \\ 10, interval \\ 50)
  def eventually(fun, 0, _interval), do: fun.()
  def eventually(fun, attempts, interval) do
    try do
      fun.()
    rescue
      _ ->
        Process.sleep(interval)
        eventually(fun, attempts - 1, interval)
    catch
      _kind, _reason ->
        Process.sleep(interval)
        eventually(fun, attempts - 1, interval)
    end
  end
end

