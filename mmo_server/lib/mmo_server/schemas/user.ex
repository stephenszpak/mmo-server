defmodule MmoServer.Schemas.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:email, :string)
    field(:password_hash, :string)
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password_hash])
    |> validate_required([:email, :password_hash])
  end
end
