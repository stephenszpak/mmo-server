defmodule MmoServer.TestHelpers do
  import ExUnit.Callbacks, only: [start_supervised: 1]

  def start_shared(process_mod, args \\ []) do
    args =
      if is_map(args) do
        Map.put(args, :sandbox_owner, self())
      else
        args
      end

    child_spec = Supervisor.child_spec({process_mod, args}, id: {process_mod, make_ref()})
    {:ok, pid} = start_supervised(child_spec)
    pid
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

