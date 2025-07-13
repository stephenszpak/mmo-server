defmodule MmoServer.Protocol.UdpServer do
  use GenServer
  require Logger

  @port 4000

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, socket} = :gen_udp.open(@port, [:binary, active: true])
    {:ok, %{socket: socket}}
  end

  @impl true
  def handle_info({:udp, _socket, _ip, _port, packet}, state) do
    Logger.debug("Received UDP: #{inspect(packet)}")

    case packet do
      <<pid::unsigned-big-32, opcode::unsigned-big-16, dx::float-big-32, dy::float-big-32, dz::float-big-32>> ->
        Logger.debug("Decoded UDP id=#{pid} opcode=#{opcode} \u0394(#{dx}, #{dy}, #{dz})")

        player_id =
          MmoServer.UnityHash.lookup_player_id(pid) || Integer.to_string(pid)

        case opcode do
          1 ->
            delta = {
              clamp(dx),
              clamp(dy),
              clamp(dz)
            }
            d0 = :erlang.float_to_binary(elem(delta, 0), decimals: 2)
            d1 = :erlang.float_to_binary(elem(delta, 1), decimals: 2)
            d2 = :erlang.float_to_binary(elem(delta, 2), decimals: 2)
            Logger.info("[UDP] Player #{player_id} moved \u0394(#{d0}, #{d1}, #{d2}) via opcode #{opcode}")
            MmoServer.Player.move(player_id, delta)
          _ ->
            :ok
        end

      _other ->
        Logger.warn("Malformed UDP packet: #{inspect(packet)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  defp clamp(v) when v > 5, do: 5.0
  defp clamp(v) when v < -5, do: -5.0
  defp clamp(v), do: v
end
