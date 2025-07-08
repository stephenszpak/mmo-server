defmodule MmoServer.MobTemplate do
  @moduledoc """
  Persistent mob templates loaded from the database.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias MmoServer.Repo

  @primary_key {:id, :string, autogenerate: false}
  schema "mob_templates" do
    field :name, :string
    field :hp, :integer
    field :damage, :integer
    field :xp_reward, :integer
    field :aggressive, :boolean, default: false
    field :loot_table, {:array, :map}
    timestamps()
  end

  @type t :: %__MODULE__{}

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:id, :name, :hp, :damage, :xp_reward, :aggressive, :loot_table])
    |> validate_required([:id, :name, :hp, :damage, :xp_reward, :aggressive, :loot_table])
  end

  @spec get!(String.t()) :: __MODULE__.t()
  def get!(template_id) do
    Repo.get!(__MODULE__, template_id)
  end

  @spec list() :: [__MODULE__.t()]
  def list do
    Repo.all(__MODULE__)
  end
end
