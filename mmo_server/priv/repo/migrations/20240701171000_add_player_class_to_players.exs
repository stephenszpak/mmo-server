defmodule MmoServer.Repo.Migrations.AddPlayerClassToPlayers do
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :player_class, references(:classes, type: :string, column: :id)
    end

    create index(:players, [:player_class])
  end
end
