defmodule Mix.Tasks.SendChat do
  use Mix.Task

  @shortdoc "Broadcast a chat message via PubSub"
  @moduledoc """
  Sends a chat message to the given topic using `Phoenix.PubSub`.

      mix send_chat chat:zone:elwynn "player1" "Hello"
  """

  @impl true
  def run([topic, from | text_parts]) do
    Mix.Task.run("app.start")
    text = Enum.join(text_parts, " ")
    Phoenix.PubSub.broadcast(MmoServer.PubSub, topic, {:chat_msg, from, text})
  end
end
