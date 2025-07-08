defmodule MmoServer.Quest do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "quests" do
    field :title, :string
    field :description, :string
    field :objectives, :map
    field :rewards, :map
    timestamps()
  end

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:title, :description, :objectives, :rewards])
    |> validate_required([:title, :description, :objectives, :rewards])
  end
end
