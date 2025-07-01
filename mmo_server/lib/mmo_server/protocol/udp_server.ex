defmodule MmoServer.Protocol.UdpServer do
  use GenServer

  @port 4000

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, socket} = :gen_udp.open(@port, [:binary, active: true])
    {:ok, %{socket: socket}}
  end

  def handle_info({:udp, _socket, _ip, _port, <<pid::32, opcode::16, x::float, y::float, z::float>>}, state) do
    case opcode do
      1 ->
        delta = {x, y, z}
        player_pid = {:via, Horde.Registry, {PlayerRegistry, pid}}
        GenServer.cast(player_pid, {:move, delta})
      _ -> :ok
    end
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end
