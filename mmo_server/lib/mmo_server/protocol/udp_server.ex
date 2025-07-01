defmodule MmoServer.Protocol.UDPServer do
  @moduledoc """
  UDP server handling player actions.
  """
  use GenServer

  @port 5555

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, socket} = :gen_udp.open(@port, [:binary, active: true])
    {:ok, Map.put(state, :socket, socket)}
  end

  @impl true
  def handle_info(
        {:udp, _socket, _ip, _port, <<player_id::32, action::16, x::float, y::float, z::float>>},
        state
      ) do
    case Horde.Registry.whereis_name({MmoServer.Registry, {:player, player_id}}) do
      pid when is_pid(pid) ->
        MmoServer.Player.move(pid, {x, y, z})

      _ ->
        :ignore
    end

    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}
end
