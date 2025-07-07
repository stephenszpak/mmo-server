defmodule MmoServer.LootDrop do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "loot_drops" do
    field :npc_id, :string
    field :item, :string
    field :zone_id, :string
    field :x, :float
    field :y, :float
    field :z, :float
    field :quality, :string
    field :owner, :string
    field :picked_up, :boolean, default: false
    timestamps()
  end

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:npc_id, :item, :zone_id, :x, :y, :z, :quality, :owner, :picked_up])
    |> validate_required([:npc_id, :item, :zone_id, :x, :y, :z, :quality, :picked_up])
  end
end
