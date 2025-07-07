defmodule MmoServer.TestHelpers do
  import ExUnit.Callbacks, only: [start_supervised: 1]

  def start_shared(process_mod, args), do: start_shared(process_mod, args, [])

  def start_shared(process_mod, args, opts) when is_list(opts) do
    opts = Keyword.merge([sandbox_owner: :new, name: nil], opts)

    {owner, started?} =
      case opts[:sandbox_owner] do
        :new ->
          {Ecto.Adapters.SQL.Sandbox.start_owner!(MmoServer.Repo, shared: true), true}
        :self ->
          {self(), false}
        pid ->
          {pid, false}
      end

    args =
      if is_map(args) do
        Map.put_new(args, :sandbox_owner, owner)
      else
        args
      end

    if process_mod == MmoServer.Player and is_map(args) and Map.has_key?(args, :player_id) do
      MmoServer.Player.stop(args.player_id)
    end

    child_spec = Supervisor.child_spec({process_mod, args}, id: opts[:name] || {process_mod, make_ref()})
    {:ok, pid} =
      case start_supervised(child_spec) do
        {:error, {:already_started, pid}} -> {:ok, pid}
        other -> other
      end

    if owner do
      Ecto.Adapters.SQL.Sandbox.allow(MmoServer.Repo, owner, pid)
    end

    ExUnit.Callbacks.on_exit(fn ->
      lookup_key =
        cond do
          process_mod == MmoServer.Player and is_map(args) -> args.player_id
          process_mod == MmoServer.Zone and is_binary(args) -> {:zone, args}
          true -> nil
        end

      if lookup_key do
        Horde.Registry.lookup(PlayerRegistry, lookup_key)
        |> Enum.each(fn {pid, _} -> if Process.alive?(pid), do: Process.exit(pid, :normal) end)
      else
        if Process.alive?(pid), do: Process.exit(pid, :normal)
      end

      if started? and Process.alive?(owner) do
        Ecto.Adapters.SQL.Sandbox.stop_owner(owner)
      end
    end)

    pid
  end

  def unique_string(prefix) do
    "#{prefix}_#{System.unique_integer([:positive])}"
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

  def base_zone(id) when is_binary(id) do
    Regex.replace(~r/_\d{8}T\d{6}$/, id, "")
  end
end

