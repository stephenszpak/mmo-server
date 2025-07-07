defmodule MmoServer.PlayerStats do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:player_id, :string, autogenerate: false}
  schema "player_stats" do
    field :xp, :integer, default: 0
    field :level, :integer, default: 1
    field :next_level_xp, :integer, default: 100
    timestamps()
  end

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:player_id, :xp, :level, :next_level_xp])
    |> validate_required([:player_id, :xp, :level, :next_level_xp])
  end
end

