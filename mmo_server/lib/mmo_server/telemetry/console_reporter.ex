defmodule MmoServer.Telemetry.ConsoleReporter do
  @moduledoc false
  use GenServer

  def start_link(metrics) do
    GenServer.start_link(__MODULE__, metrics, name: __MODULE__)
  end

  @impl true
  def init(metrics) do
    events = Enum.map(metrics, & &1.event_name)
    :telemetry.attach_many("mmo_server-console-reporter", events, &__MODULE__.handle_event/4, nil)
    {:ok, metrics}
  end

  def handle_event(_event, _measurements, _metadata, _config) do
    :ok
  end

  @impl true
  def terminate(_, _state) do
    :telemetry.detach("mmo_server-console-reporter")
    :ok
  end
end
