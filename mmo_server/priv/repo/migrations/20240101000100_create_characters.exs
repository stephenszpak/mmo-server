defmodule MmoServer.Repo.Migrations.CreateCharacters do
  use Ecto.Migration

  def change do
    create table(:characters) do
      add :user_id, references(:users), null: false
      add :name, :string, null: false
      add :level, :integer, default: 1
      timestamps()
    end

    create index(:characters, [:user_id])
  end
end
