defmodule MmoServer.CombatEngine do
  @moduledoc """
  Processes combat ticks at 10 Hz.
  """
  use GenServer

  @tick 100

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    :timer.send_interval(@tick, :tick)
    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    # combat resolution logic goes here
    {:noreply, state}
  end

  @impl true
  def handle_info({:player_position, _id, _pos}, state) do
    # track positions for combat
    {:noreply, state}
  end
end
