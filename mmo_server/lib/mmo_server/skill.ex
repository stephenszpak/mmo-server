defmodule MmoServer.Skill do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :integer, autogenerate: false}
  schema "skills" do
    belongs_to :class, MmoServer.Class, type: :string
    field :name, :string
    field :description, :string
    field :cooldown, :integer
    field :type, :string
    timestamps()
  end

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:id, :class_id, :name, :description, :cooldown, :type])
    |> validate_required([:id, :class_id, :name, :description, :cooldown, :type])
  end
end
