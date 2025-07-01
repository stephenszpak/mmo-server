defmodule MmoServer.PromEx do
  use PromEx, otp_app: :mmo_server

  @impl true
  def plugins do
    [
      PromEx.Plugins.Phoenix,
      PromEx.Plugins.Ecto
    ]
  end

  @impl true
  def dashboards, do: []
end
