defmodule MmoServer.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias MmoServer.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import MmoServer.DataCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MmoServer.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(MmoServer.Repo, {:shared, self()})
    end

    :ok
  end
end
