defmodule MmoServer.Repo.Migrations.ChangeWorldStateValueType do
  use Ecto.Migration

  def change do
    alter table(:world_state) do
      modify :value, :text
    end
  end
end
