defmodule MmoServerWeb.Telemetry do
  @moduledoc false
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    metrics = [
      summary("phoenix.endpoint.stop.duration", unit: {:native, :millisecond}),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      )
    ]

    children = [
      {TelemetryMetricsPromEx, metrics: metrics}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
