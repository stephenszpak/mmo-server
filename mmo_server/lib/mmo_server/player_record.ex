defmodule MmoServer.PlayerRecord do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Phoenix.Param, key: :id}
  schema "players" do
    field :player_id, :string
    field :zone_id, :string
    timestamps()
  end

  def changeset(player, attrs) do
    player
    |> cast(attrs, [:player_id, :zone_id])
    |> validate_required([:player_id, :zone_id])
    |> unique_constraint(:player_id)
  end
end
