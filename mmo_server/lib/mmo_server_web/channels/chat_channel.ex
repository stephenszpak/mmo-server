defmodule MmoServerWeb.ChatChannel do
  @moduledoc """
  Realtime chat channel used by the MMO server.

  Clients can join different topics for global, zone and private
  (whisper) chat.  Each message pushed through the channel is broadcast
  to all subscribers of the topic and is also consumable via
  `Phoenix.PubSub` for systems that do not connect through websockets.

  Expected payload for the `"message"` event:

      %{"text" => text, "from" => player_id, "to" => topic}

  The server will enrich the message by adding a timestamp and echoing
  it back to the sender.
  """

  use Phoenix.Channel

  alias Phoenix.PubSub
  alias MmoServer.PubSub, as: MMO

  @impl true
  def join("chat:global" = topic, _params, socket) do
    PubSub.subscribe(MMO, topic)
    {:ok, socket}
  end

  @impl true
  def join("chat:zone:" <> _zone_id = topic, _params, socket) do
    PubSub.subscribe(MMO, topic)
    {:ok, socket}
  end

  @impl true
  def join("chat:whisper:" <> _player_id = topic, _params, socket) do
    # In a real system we would verify that only the sender and
    # recipient join this topic.  The server simply subscribes the
    # socket to the whisper topic so that only those connected will see
    # the messages.
    PubSub.subscribe(MMO, topic)
    {:ok, socket}
  end

  @impl true
  def handle_in("message", %{"text" => text, "from" => from, "to" => to}, socket) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    msg = %{
      "type" => "chat",
      "from" => from,
      "to" => to,
      "text" => text,
      "timestamp" => timestamp
    }

    case socket.topic do
      "chat:whisper:" <> _id ->
        broadcast!(socket, "message", msg)
        push(socket, "message", msg)

      _ ->
        broadcast!(socket, "message", msg)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:chat_msg, from, text}, socket) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    push(socket, "message", %{
      "type" => "chat",
      "from" => from,
      "to" => socket.topic,
      "text" => text,
      "timestamp" => timestamp
    })

    {:noreply, socket}
  end
end
