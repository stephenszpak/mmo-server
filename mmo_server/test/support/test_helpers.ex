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

    ExUnit.Callbacks.on_exit(fn ->
      if is_map(args) and process_mod == MmoServer.Player and Map.has_key?(args, :player_id) do
        MmoServer.Player.stop(args.player_id)
      end

      if Process.alive?(pid), do: Process.exit(pid, :normal)
    end)

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

