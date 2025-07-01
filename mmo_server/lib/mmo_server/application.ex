defmodule MmoServer.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MmoServer.Repo,
      MmoServerWeb.Telemetry,
      {Phoenix.PubSub, name: MmoServer.PubSub},
      MmoServerWeb.Endpoint,
      MmoServerWeb.Presence,
      MmoServer.Protocol.UdpServer,
      MmoServer.CombatEngine,
      {Horde.Registry, [name: PlayerRegistry, keys: :unique]},
      {MmoServer.PlayerSupervisor, []},
      {MmoServer.ZoneSupervisor, []}
    ]

    opts = [strategy: :one_for_one, name: MmoServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    MmoServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
