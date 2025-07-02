defmodule MmoServer.PlayerPersistence do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @derive {Jason.Encoder, only: [:id, :zone_id, :x, :y, :z, :hp, :status]}
  schema "players" do
    field(:zone_id, :string)
    field(:x, :float)
    field(:y, :float)
    field(:z, :float)
    field(:hp, :integer)
    field(:status, :string)
    timestamps()
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:id, :zone_id, :x, :y, :z, :hp, :status])
    |> validate_required([:id, :zone_id, :x, :y, :z, :hp, :status])
  end
end
