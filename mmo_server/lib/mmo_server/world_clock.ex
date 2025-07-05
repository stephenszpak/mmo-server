defmodule MmoServer.WorldClock do
  @moduledoc """
  Centralized world clock dispatching timed events across the MMO.
  """

  use GenServer

  @tick_ms Application.compile_env(:mmo_server, :world_tick_ms, 60_000)
  @boss_every Application.compile_env(:mmo_server, :boss_every, 10)
  @storm_chance Application.compile_env(:mmo_server, :storm_chance, 0.05)

  ## Client API

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  ## Server callbacks

  @impl true
  def init(state) do
    :timer.send_interval(@tick_ms, :tick)
    {:ok, Map.put(state, :count, 0)}
  end

  @impl true
  def handle_info(:tick, %{count: c} = state) do
    count = c + 1
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "world:clock", {:tick, count})

    if rem(count, @boss_every) == 0 do
      MmoServer.WorldEvents.spawn_world_boss()
    end

    if :rand.uniform() < @storm_chance do
      MmoServer.WorldEvents.storm_event()
    end

    {:noreply, %{state | count: count}}
  end
end
