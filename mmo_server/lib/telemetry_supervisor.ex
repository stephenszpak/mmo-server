defmodule Telemetry.Supervisor do
  @moduledoc false

  use Supervisor

  @doc false
  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {MmoServer.Telemetry.ConsoleReporter, MmoServer.Metrics.metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
