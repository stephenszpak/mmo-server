defmodule MmoServer.Repo.Migrations.CreatePlayerStats do
  use Ecto.Migration

  def change do
    create table(:player_stats, primary_key: false) do
      add :player_id, :string, primary_key: true
      add :xp, :integer, null: false, default: 0
      add :level, :integer, null: false, default: 1
      add :next_level_xp, :integer, null: false, default: 100
      timestamps()
    end
  end
end

