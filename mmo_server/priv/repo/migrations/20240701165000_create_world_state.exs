defmodule MmoServer.Repo.Migrations.CreateWorldState do
  use Ecto.Migration

  def change do
    create table(:world_state, primary_key: false) do
      add :key, :string, primary_key: true
      add :value, :map
      timestamps()
    end
  end
end
