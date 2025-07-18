defmodule MmoServer.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MmoServer.Repo,
      MmoServer.WorldState,
      MmoServerWeb.Telemetry,
      {Phoenix.PubSub, name: MmoServer.PubSub},
      MmoServerWeb.Endpoint,
      MmoServerWeb.Presence,
      # Only start the UDP server in dev or prod. Skipping it in other
      # environments (like :test) lets us run multiple nodes without
      # fighting over the same UDP port.
      if(Mix.env() in [:dev, :prod], do: MmoServer.Protocol.UdpServer),
      MmoServer.CombatEngine,
      MmoServer.DebuffSystem,
      MmoServer.WorldClock,
      {Horde.Registry, [name: PlayerRegistry, keys: :unique]},
      {Horde.Registry, [name: NPCRegistry, keys: :unique]},
      {MmoServer.PlayerSupervisor, []},
      {MmoServer.ZoneSupervisor, []},
      {MmoServer.InstanceManager, []}
    ]
    |> Enum.filter(& &1)
    |> Kernel.++(maybe_bootstrap())

    opts = [strategy: :one_for_one, name: MmoServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    MmoServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp maybe_bootstrap do
    if Mix.env() == :test do
      []
    else
      [MmoServer.Bootstrap]
    end
  end
end
