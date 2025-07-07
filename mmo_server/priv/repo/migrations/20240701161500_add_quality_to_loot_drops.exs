defmodule MmoServer.Repo.Migrations.AddQualityToLootDrops do
  use Ecto.Migration

  def change do
    alter table(:loot_drops) do
      add :quality, :string, null: false, default: "common"
    end
  end
end
