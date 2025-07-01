defmodule MmoServer.Application do
  @moduledoc """
  Entry point for the MMO server application.
  Starts supervisors for zones, players, persistence and networking.
  """
  use Application

  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies, [])

    children = [
      {Cluster.Supervisor, [topologies, [name: MmoServer.ClusterSupervisor]]},
      MmoServer.Repo,
      {Phoenix.PubSub, name: MmoServer.PubSub},
      MmoServerWeb.Endpoint,
      MmoServer.PromEx,
      {Horde.Registry, [keys: :unique, name: MmoServer.Registry]},
      {MmoServer.ZoneSupervisor, []},
      {MmoServer.PlayerSupervisor, []},
      MmoServer.CombatEngine,
      MmoServer.PersistenceWorker,
      MmoServer.Protocol.UDPServer
    ]

    opts = [strategy: :one_for_one, name: MmoServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    MmoServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
