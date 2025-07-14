defmodule MmoServerWeb.ChatChannel do
  @moduledoc """
  Realtime chat channel used by the MMO server.

  Clients join one of the following topics:
    * `"chat:global"`
    * `"chat:zone:<zone_id>"`
    * `"chat:whisper:<player_id>"`

  Each `"message"` event expects a payload like:

      %{"from" => "player1", "text" => "Hello"}

  The payload is broadcast to all subscribers of the topic.
  You can manually test broadcasting from `IEx` with:

      Phoenix.PubSub.broadcast(MmoServer.PubSub, "chat:global", {:chat_msg, "gm", "Server restart in 5 minutes"})
  """

  use Phoenix.Channel

  require Logger
  alias Phoenix.PubSub
  alias MmoServer.PubSub, as: MMO

  @impl true
  def join("chat:global" = topic, _params, socket) do
    Logger.info("Joined #{topic}")
    PubSub.subscribe(MMO, topic)
    {:ok, socket}
  end

  @impl true
  def join("chat:zone:" <> _zone_id = topic, _params, socket) do
    Logger.info("Joined #{topic}")
    PubSub.subscribe(MMO, topic)
    {:ok, socket}
  end

  @impl true
  def join("chat:whisper:" <> _player_id = topic, _params, socket) do
    Logger.info("Joined #{topic}")
    PubSub.subscribe(MMO, topic)
    {:ok, socket}
  end

  @impl true
  def handle_in("message", payload = %{"from" => _from, "text" => _text}, socket) do
    Logger.info("Received #{inspect(payload)} on #{socket.topic}")
    broadcast!(socket, "message", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:chat_msg, from, text} = msg, socket) do
    Logger.info("PubSub #{inspect(msg)}")
    push(socket, "message", %{"from" => from, "text" => text})
    {:noreply, socket}
  end

  def handle_info(msg, socket) do
    Logger.warn("Unhandled message: #{inspect(msg)}")
    {:noreply, socket}
  end
end
