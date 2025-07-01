defmodule MmoServer.PlayerSupervisor do
  @moduledoc """
  Dynamic supervisor managing player processes.
  """
  use Horde.DynamicSupervisor

  def start_link(init_arg) do
    Horde.DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Horde.DynamicSupervisor.init(strategy: :one_for_one)
  end
end
