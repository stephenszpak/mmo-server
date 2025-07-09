defmodule MmoServer.Repo.Migrations.ExtendSkills do
  use Ecto.Migration

  def change do
    alter table(:skills) do
      add :effect_type, :string
      add :radius, :integer
      add :debuff, :map
      add :condition, :string
    end
  end
end
