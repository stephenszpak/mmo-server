defmodule MmoServer.Protocol.UdpServer do
  use GenServer
  require Logger

  @port 4000

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    case :gen_udp.open(@port, [:binary, active: true]) do
      {:ok, socket} -> {:ok, Map.put(state, :socket, socket)}
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_info({:udp, _socket, _ip, _port, packet}, state) do
    case decode(packet) do
      {:ok, player_id, opcode, dx, dy, dz} ->
        Logger.debug("player_id=#{player_id} opcode=#{opcode} dx=#{dx} dy=#{dy} dz=#{dz}")
        if opcode == 1 do
          GenServer.cast({:via, Horde.Registry, {PlayerRegistry, player_id}}, {:move, {dx, dy, dz}})
        end
      {:error, _reason} ->
        Logger.warn("Unknown or malformed UDP packet: #{inspect(packet)}")
    end
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  defp decode(packet) do
    try do
      <<len::unsigned-integer-8, id::binary-size(len), op::unsigned-big-integer-16,
        dx::float-big-32, dy::float-big-32, dz::float-big-32>> = packet
      {:ok, String.Chars.to_string(id), op, dx, dy, dz}
    rescue
      _ -> {:error, :decode_error}
    end
  end
end
