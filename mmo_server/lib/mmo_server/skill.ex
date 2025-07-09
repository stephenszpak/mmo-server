defmodule MmoServer.Skill do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "skills" do
    belongs_to :class, MmoServer.Class, type: :string
    field :name, :string
    field :description, :string
    field :cooldown, :integer
    field :type, :string
    field :effect_type, :string
    field :radius, :integer
    field :debuff, :map
    field :condition, :string
    timestamps()
  end

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [
      :class_id,
      :name,
      :description,
      :cooldown,
      :type,
      :effect_type,
      :radius,
      :debuff,
      :condition
    ])
    |> validate_required([:class_id, :name, :description, :cooldown, :type])
  end
end
