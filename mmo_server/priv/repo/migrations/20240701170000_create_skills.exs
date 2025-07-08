defmodule MmoServer.Repo.Migrations.CreateSkills do
  use Ecto.Migration

  def change do
    create table(:skills, primary_key: false) do
      add :id, :integer, primary_key: true
      add :class_id, references(:classes, type: :string, column: :id), null: false
      add :name, :string, null: false
      add :description, :text, null: false
      add :cooldown, :integer, null: false
      add :type, :string, null: false
      timestamps()
    end

    create index(:skills, [:class_id])
    create unique_index(:skills, [:class_id, :name])
    create constraint(:skills, :id_range, check: "id >= 0 AND id <= 9999")
  end
end
