defmodule MmoServer.QuestProgress do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "quest_progress" do
    field :quest_id, :binary_id
    field :player_id, :string
    field :progress, {:array, :map}
    field :completed, :boolean, default: false
    timestamps()
  end

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:quest_id, :player_id, :progress, :completed])
    |> validate_required([:quest_id, :player_id, :progress, :completed])
  end
end
