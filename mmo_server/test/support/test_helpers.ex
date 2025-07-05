defmodule MmoServer.TestHelpers do
  import ExUnit.Callbacks, only: [start_supervised: 1]

  def start_shared(process_mod, args \\ []) do
    args =
      cond do
        is_map(args) -> Map.put(args, :sandbox_owner, self())
        process_mod == MmoServer.Zone -> %{zone_id: args, sandbox_owner: self()}
        true -> args
      end

    if process_mod == MmoServer.Player and is_map(args) and Map.has_key?(args, :player_id) do
      MmoServer.Player.stop(args.player_id)
    end

    child_spec = Supervisor.child_spec({process_mod, args}, id: {process_mod, make_ref()})
    {:ok, pid} =
      case start_supervised(child_spec) do
        {:error, {:already_started, pid}} -> {:ok, pid}
        other -> other
      end

    assert_receive {:ready, ^pid}, 1_000

    if is_map(args) and Map.has_key?(args, :sandbox_owner) and args.sandbox_owner do
      Ecto.Adapters.SQL.Sandbox.allow(MmoServer.Repo, args.sandbox_owner, pid)
    end


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

