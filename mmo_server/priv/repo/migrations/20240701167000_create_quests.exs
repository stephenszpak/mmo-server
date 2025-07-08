defmodule MmoServer.Repo.Migrations.CreateQuests do
  use Ecto.Migration

  def change do
    create table(:quests, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :title, :string, null: false
      add :description, :text, null: false
      add :objectives, :map, null: false
      add :rewards, :map, null: false
      timestamps()
    end
  end
end
