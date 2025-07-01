defmodule MmoServerWeb do
  def controller do
    quote do
      use Phoenix.Controller, namespace: MmoServerWeb
      import Plug.Conn
      alias MmoServerWeb.Router.Helpers, as: Routes
    end
  end

  def router do
    quote do
      use Phoenix.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/mmo_server_web/templates",
        namespace: MmoServerWeb
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
