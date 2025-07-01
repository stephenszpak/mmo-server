defmodule MmoServerWeb.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/api", MmoServerWeb do
    pipe_through :api
  end

  scope "/", MmoServerWeb do
    pipe_through :browser

    live "/players", PlayerDashboardLive
    live "/test", TestControlLive
  end
end
