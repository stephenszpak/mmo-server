defmodule MmoServer.Repo.Migrations.CreateClasses do
  use Ecto.Migration

  def change do
    create table(:classes, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :role, :string, null: false
      add :lore, :text, null: false
      timestamps()
    end
  end
end
