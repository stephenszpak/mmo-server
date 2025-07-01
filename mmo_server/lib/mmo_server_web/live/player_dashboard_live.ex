defmodule MmoServerWeb.PlayerDashboardLive do
  use Phoenix.LiveView, layout: false
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(1000, :refresh)

    players =
      Horde.Registry.select(PlayerRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
      |> Enum.map(fn id ->
        {x, y, z} = GenServer.call({:via, Horde.Registry, {PlayerRegistry, id}}, :get_position)
        {id, {x, y, z}}
      end)
      |> Enum.into(%{})

    Logger.debug("Dashboard mount players: #{inspect(players)}")

    {:ok, assign(socket, players: players)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    players =
      Horde.Registry.select(PlayerRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
      |> Enum.map(fn id ->
        {x, y, z} = GenServer.call({:via, Horde.Registry, {PlayerRegistry, id}}, :get_position)
        {id, {x, y, z, DateTime.utc_now()}}
      end)
      |> Enum.into(%{})

    Logger.debug("Dashboard refresh: #{inspect(players)}")
    {:noreply, assign(socket, players: players)}
  end
end
