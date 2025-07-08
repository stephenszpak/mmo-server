defmodule MmoServer.Repo.Migrations.CreateQuestProgress do
  use Ecto.Migration

  def change do
    create table(:quest_progress, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :quest_id, :uuid, null: false
      add :player_id, :string, null: false
      add :progress, {:array, :map}, null: false
      add :completed, :boolean, null: false, default: false
      timestamps()
    end

    create index(:quest_progress, [:player_id])
    create unique_index(:quest_progress, [:quest_id, :player_id])
  end
end
