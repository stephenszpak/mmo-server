defmodule MmoServer.Repo.Migrations.CreatePlayers do
  use Ecto.Migration

  def change do
    create table(:players, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :player_id, :string, null: false
      add :zone_id, :string, null: false
      timestamps()
    end

    create unique_index(:players, [:player_id])
  end
end
