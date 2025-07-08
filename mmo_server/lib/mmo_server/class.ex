defmodule MmoServer.Class do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "classes" do
    field :name, :string
    field :role, :string
    field :lore, :string
    has_many :skills, MmoServer.Skill, foreign_key: :class_id
    timestamps()
  end

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:id, :name, :role, :lore])
    |> validate_required([:id, :name, :role, :lore])
  end
end
