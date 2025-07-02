defmodule MmoServer.Repo.Migrations.CreatePlayers do
  use Ecto.Migration

  def change do
    create table(:players, primary_key: false) do
      add :id, :string, primary_key: true
      add :zone_id, :string, null: false
      add :x, :float, null: false
      add :y, :float, null: false
      add :z, :float, null: false
      add :hp, :integer, null: false
      add :status, :string, null: false
      timestamps()
    end
  end
end
