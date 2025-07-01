defmodule MmoServerWeb.EventChannel do
  @moduledoc """
  Channel for server events.
  """
  use Phoenix.Channel

  def join("events:" <> _subtopic, _payload, socket) do
    {:ok, socket}
  end
end
