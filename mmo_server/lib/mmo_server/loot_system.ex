defmodule MmoServer.LootSystem do
  @moduledoc """
  Handles creation and pickup of loot drops.
  """

  require Logger
  alias MmoServer.{Repo, LootDrop, Player}
  alias MmoServer.Player.Inventory

  @pickup_radius 5

  @spec drop_for_npc(MmoServer.NPC.t()) :: :ok
  def drop_for_npc(%MmoServer.NPC{id: id, template: template, zone_id: zone, pos: {x, y}}) do
    template.loot_table
    |> Enum.each(fn %{item: item, quality: quality, chance: chance} ->
      if :rand.uniform() < chance do
        %LootDrop{}
        |> LootDrop.changeset(%{
          npc_id: to_string(id),
          item: item,
          zone_id: zone,
          x: x,
          y: y,
          z: 0.0,
          quality: quality,
          picked_up: false
        })
        |> Repo.insert()
        |> case do
          {:ok, drop} ->
            Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{zone}", {:loot_dropped, drop})
            Logger.info("Dropped #{item} [#{quality}] at #{zone}")
            :ok
          _ -> :ok
        end
      end
    end)

    :ok
  end

  @spec pickup(String.t(), Ecto.UUID.t()) :: {:ok, LootDrop.t()} | {:error, term()}
  def pickup(player_id, loot_id) do
    Repo.transaction(fn ->
      with %LootDrop{} = drop <- Repo.get(LootDrop, loot_id),
           false <- drop.picked_up,
           {px, py, pz} <- Player.get_position(player_id),
           true <- within_radius?({drop.x, drop.y, drop.z}, {px, py, pz}) do
        changeset =
          LootDrop.changeset(drop, %{owner: player_id, picked_up: true})

        {:ok, updated} = Repo.update(changeset)
        Inventory.add_item(player_id, %{item: drop.item, quality: drop.quality})
        MmoServer.Quests.record_progress(
          player_id,
          MmoServer.Quests.pelt_collect_id(),
          %{type: "collect", target: drop.item}
        )
        Phoenix.PubSub.broadcast(MmoServer.PubSub, "zone:#{drop.zone_id}", {:loot_picked_up, player_id, drop.item})
        updated
      else
        _ -> Repo.rollback(:invalid_pickup)
      end
    end)
  end

  defp within_radius?({x1, y1, z1}, {x2, y2, z2}) do
    dist = :math.sqrt(:math.pow(x1 - x2, 2) + :math.pow(y1 - y2, 2) + :math.pow(z1 - z2, 2))
    dist <= @pickup_radius
  end
end
