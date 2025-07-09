defmodule MmoServerWeb.BossTestLive do
  use Phoenix.LiveView, layout: false

  require Logger
  alias MmoServer.{Player, SkillMetadata}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MmoServer.PubSub, "combat:log")
    end

    {:ok,
     socket
     |> assign(:players, fetch_players())
     |> assign(:bosses, fetch_bosses())
     |> assign(:selected_player, nil)
     |> assign(:selected_boss, nil)
     |> assign(:available_skills, SkillMetadata.get_all_skills())
     |> assign(:logs, [])}
  end

  defp fetch_players do
    Horde.Registry.select(PlayerRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&player_info/1)
  end

  defp player_info(id) do
    case Horde.Registry.lookup(PlayerRegistry, id) do
      [{pid, _}] ->
        if Process.alive?(pid) do
          try do
            s = :sys.get_state(pid)
            %{id: id, zone: s.zone_id, hp: s.hp, status: s.status}
          catch
            _, _ -> %{id: id, zone: nil, hp: nil, status: nil}
          end
        else
          %{id: id, zone: nil, hp: nil, status: nil}
        end

      _ ->
        %{id: id, zone: nil, hp: nil, status: nil}
    end
  end

  defp fetch_bosses do
    Horde.Registry.select(NPCRegistry, [{{{:npc, :"$1"}, :_, :_}, [], [:"$1"]}])
    |> Enum.map(&npc_info/1)
    |> Enum.filter(&(&1.type == :boss))
  end

  defp npc_info(id) do
    case Horde.Registry.lookup(NPCRegistry, {:npc, id}) do
      [{pid, _}] ->
        if Process.alive?(pid) do
          try do
            s = :sys.get_state(pid)
            %{
              id: id,
              zone: s.zone_id,
              type: s.type,
              hp: s.hp,
              status: s.status,
              boss_name: s.boss_name,
              phase: Map.get(s, :phase)
            }
          catch
            _, _ -> %{id: id, zone: nil, type: nil, hp: nil, status: nil}
          end
        else
          %{id: id, zone: nil, type: nil, hp: nil, status: nil}
        end

      _ ->
        %{id: id, zone: nil, type: nil, hp: nil, status: nil}
    end
  end

  defp refresh_state(socket) do
    socket
    |> assign(:players, fetch_players())
    |> assign(:bosses, fetch_bosses())
  end

  defp log(socket, msg) do
    assign(socket, :logs, [msg | socket.assigns.logs] |> Enum.take(50))
  end

  @impl true
  def handle_event("select_player", %{"player" => id}, socket) do
    {:noreply, assign(socket, :selected_player, id)}
  end

  def handle_event("select_boss", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_boss, id)}
  end

  def handle_event("attack_boss", _params, %{assigns: %{selected_player: p, selected_boss: b}} = socket)
      when is_binary(p) and is_binary(b) do
    Logger.debug("#{p} attacks #{b}")
    Player.attack_boss(p, b)
    {:noreply, log(socket, "#{p} attacked #{b}") |> refresh_state()}
  end

  def handle_event("use_skill", %{"skill" => skill}, %{assigns: %{selected_player: p, selected_boss: b}} = socket)
      when is_binary(p) and is_binary(b) do
    Logger.debug("#{p} uses #{skill} on #{b}")
    Player.cast_skill_on_boss(p, b, skill)
    {:noreply, log(socket, "#{p} used #{skill} on #{b}") |> refresh_state()}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:combat_log, msg}, socket) do
    {:noreply, log(socket, msg)}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, refresh_state(socket)}
  end
end

