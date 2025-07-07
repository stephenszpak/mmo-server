defmodule MmoServer.Player.Inventory do
  @moduledoc """
  Persistence helpers for player inventories.
  """

  import Ecto.Query
  alias MmoServer.{Repo, InventoryItem}

  @doc "Add an item to a player's inventory."
  @spec add_item(String.t(), map()) :: {:ok, InventoryItem.t()} | {:error, Ecto.Changeset.t()}
  def add_item(player_id, attrs) do
    %InventoryItem{}
    |> InventoryItem.changeset(Map.put(attrs, :player_id, player_id))
    |> Repo.insert()
  end

  @doc "List all inventory items for a player"
  def list(player_id) do
    Repo.all(from i in InventoryItem, where: i.player_id == ^player_id)
  end

  @doc "Equip an item into the given slot. Existing item in that slot is unequipped"
  def equip(player_id, item_id, slot \\ "main_hand") do
    Repo.transaction(fn ->
      from(i in InventoryItem,
        where: i.player_id == ^player_id and i.slot == ^slot and i.equipped == true
      )
      |> Repo.update_all(set: [equipped: false, slot: nil])

      item = Repo.get_by!(InventoryItem, id: item_id, player_id: player_id)

      item
      |> InventoryItem.changeset(%{equipped: true, slot: slot})
      |> Repo.update()
    end)
  end

  @doc "Unequip whatever item is equipped in the slot"
  def unequip(player_id, slot) do
    from(i in InventoryItem,
      where: i.player_id == ^player_id and i.slot == ^slot and i.equipped == true
    )
    |> Repo.update_all(set: [equipped: false, slot: nil])

    :ok
  end

  @doc "Return all equipped items for a player"
  def get_equipped(player_id) do
    Repo.all(from i in InventoryItem, where: i.player_id == ^player_id and i.equipped == true)
  end
end
