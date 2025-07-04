ExUnit.start(formatters: [ExUnit.CLIFormatter, MmoServer.PassingFormatter])
{:ok, _} = Application.ensure_all_started(:mmo_server)
Ecto.Adapters.SQL.Sandbox.mode(MmoServer.Repo, :manual)
