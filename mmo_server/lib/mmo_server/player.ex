defmodule MmoServer.Player do
  @moduledoc """
  Represents a connected player.
  """
  use GenServer

  @type state :: %{
          id: integer(),
          zone: pid(),
          position: {float(), float(), float()}
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via(opts[:id]))
  end

  defp via(id), do: {:via, Horde.Registry, {MmoServer.Registry, {:player, id}}}

  @impl true
  def init(opts) do
    {:ok,
     %{
       id: opts[:id],
       zone: opts[:zone],
       position: {0.0, 0.0, 0.0}
     }}
  end

  @spec move(pid(), {float(), float(), float()}) :: :ok
  def move(pid, pos), do: GenServer.cast(pid, {:move, pos})

  @impl true
  def handle_cast({:move, pos}, state) do
    send(state.zone, {:player_moved, state.id, pos})
    {:noreply, %{state | position: pos}}
  end
end
