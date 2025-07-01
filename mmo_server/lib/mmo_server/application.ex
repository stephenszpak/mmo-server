defmodule MmoServer.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      MmoServerWeb.Telemetry,
      {Phoenix.PubSub, name: MmoServer.PubSub},
      MmoServerWeb.Endpoint,
      MmoServerWeb.Presence,
      MmoServer.Protocol.UdpServer,
      {Horde.Registry, [name: PlayerRegistry, keys: :unique]},
      {Horde.DynamicSupervisor, [name: PlayerSupervisor, strategy: :one_for_one]},
      {Horde.DynamicSupervisor, [name: ZoneSupervisor, strategy: :one_for_one]}
    ]

    opts = [strategy: :one_for_one, name: MmoServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    MmoServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
