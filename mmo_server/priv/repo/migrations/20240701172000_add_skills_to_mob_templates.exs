defmodule MmoServer.Repo.Migrations.AddSkillsToMobTemplates do
  use Ecto.Migration

  def change do
    alter table(:mob_templates) do
      add :skills, {:array, :map}, default: []
    end
  end
end
