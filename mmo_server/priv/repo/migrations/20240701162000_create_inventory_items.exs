defmodule MmoServer.Repo.Migrations.CreateInventoryItems do
  use Ecto.Migration

  def change do
    create table(:inventory_items, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :player_id, :string, null: false
      add :item, :string, null: false
      add :quality, :string, null: false
      add :equipped, :boolean, null: false, default: false
      add :slot, :string
      timestamps()
    end

    create index(:inventory_items, [:player_id])
    create index(:inventory_items, [:equipped])
  end
end
