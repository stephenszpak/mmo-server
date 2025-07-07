defmodule MmoServer.Repo.Migrations.CreateLootDrops do
  use Ecto.Migration

  def change do
    create table(:loot_drops, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :npc_id, :string, null: false
      add :item, :string, null: false
      add :zone_id, :string, null: false
      add :x, :float, null: false
      add :y, :float, null: false
      add :z, :float, null: false
      add :owner, :string
      add :picked_up, :boolean, null: false, default: false
      timestamps()
    end

    create index(:loot_drops, [:zone_id])
    create index(:loot_drops, [:item])
    create index(:loot_drops, [:picked_up])
    create index(:loot_drops, [:x, :y, :z])
  end
end
