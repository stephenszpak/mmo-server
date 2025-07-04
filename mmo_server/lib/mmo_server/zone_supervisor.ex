defmodule MmoServer.ZoneSupervisor do
  use Horde.DynamicSupervisor

  def start_link(arg) do
    Horde.DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    Horde.DynamicSupervisor.init(strategy: :one_for_one)
  end
end
