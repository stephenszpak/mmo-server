defmodule MmoServer.InventoryItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "inventory_items" do
    field :player_id, :string
    field :item, :string
    field :quality, :string
    field :equipped, :boolean, default: false
    field :slot, :string
    timestamps()
  end

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:player_id, :item, :quality, :equipped, :slot])
    |> validate_required([:player_id, :item, :quality])
  end
end
