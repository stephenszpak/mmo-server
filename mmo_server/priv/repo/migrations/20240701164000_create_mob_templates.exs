defmodule MmoServer.Repo.Migrations.CreateMobTemplates do
  use Ecto.Migration

  def change do
    create table(:mob_templates, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :hp, :integer, null: false
      add :damage, :integer, null: false
      add :xp_reward, :integer, null: false
      add :aggressive, :boolean, null: false, default: false
      add :loot_table, :map, null: false
      timestamps()
    end
  end
end
