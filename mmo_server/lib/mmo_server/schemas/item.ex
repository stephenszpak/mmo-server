defmodule MmoServer.Schemas.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "items" do
    field(:slot, :integer)
    field(:item_id, :integer)
    field(:quantity, :integer, default: 1)
    belongs_to(:character, MmoServer.Schemas.Character)
    timestamps()
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:slot, :item_id, :quantity, :character_id])
    |> validate_required([:slot, :item_id, :character_id])
  end
end
