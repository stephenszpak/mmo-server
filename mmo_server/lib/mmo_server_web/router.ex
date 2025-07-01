defmodule MmoServerWeb.Router do
  use MmoServerWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/api", MmoServerWeb do
    pipe_through(:api)
  end

  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router
    import PromEx.Plug

    scope "/" do
      pipe_through(:api)
      live_dashboard("/dashboard", metrics: MmoServerWeb.Telemetry)
      get("/metrics", PromEx.Plug, prom_ex_module: MmoServer.PromEx)
    end
  end
end
