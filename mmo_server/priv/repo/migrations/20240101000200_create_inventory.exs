defmodule MmoServer.Repo.Migrations.CreateInventory do
  use Ecto.Migration

  def change do
    create table(:items) do
      add :character_id, references(:characters), null: false
      add :slot, :integer
      add :item_id, :integer
      add :quantity, :integer, default: 1
      timestamps()
    end

    create index(:items, [:character_id])
  end
end
