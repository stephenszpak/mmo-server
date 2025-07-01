defmodule MmoServer.Schemas.Character do
  use Ecto.Schema
  import Ecto.Changeset

  schema "characters" do
    field(:name, :string)
    field(:level, :integer, default: 1)
    belongs_to(:user, MmoServer.Schemas.User)
    timestamps()
  end

  def changeset(char, attrs) do
    char
    |> cast(attrs, [:name, :level, :user_id])
    |> validate_required([:name, :user_id])
  end
end
