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

  def handle_info({:udp, _socket, _ip, _port, <<pid::32, opcode::16, dx::float, dy::float, dz::float>>}, state) do
    case opcode do
      1 ->
        delta = {
          clamp(dx),
          clamp(dy),
          clamp(dz)
        }
        MmoServer.Player.move(pid, delta)
      _ ->
        :ok
    end
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp clamp(v) when v > 5, do: 5.0
  defp clamp(v) when v < -5, do: -5.0
  defp clamp(v), do: v
end
