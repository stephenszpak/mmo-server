defmodule MmoServerWeb.PlayerDashboardLive do
  use Phoenix.LiveView, layout: false
  import PhoenixHTMLHelpers.Tag
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    # start periodic updates only when the client is connected
    if connected?(socket), do: :timer.send_interval(1000, :refresh)

    players =
      "zone1"
      |> MmoServer.Zone.get_position()
      # ETS returns tuples like {player_id, {x, y, z}}
      # Safely pattern match that structure and ignore malformed entries
      |> Enum.flat_map(fn
        {id, {x, y, z}} when not is_nil(id) ->
          [%{id: id, x: x, y: y, z: z}]
        _ ->
          []
      end)

    {:ok, assign(socket, players: players)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    players =
      Horde.Registry.select(PlayerRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
      |> Enum.filter(&is_binary/1)
      |> Enum.map(fn id ->
        {x, y, z} = GenServer.call({:via, Horde.Registry, {PlayerRegistry, id}}, :get_position)
        {id, {x, y, z, DateTime.utc_now()}}
      end)
      |> Enum.into(%{})

    Logger.debug("Dashboard refresh: #{inspect(players)}")
    {:noreply, assign(socket, players: players)}
  end
end
