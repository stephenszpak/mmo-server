defmodule MmoServer.PersistenceWorker do
  @moduledoc """
  Flushes events to Postgres using Broadway.
  """
  use Broadway

  alias Broadway.Message

  def start_link(_opts) do
    Broadway.start_link(__MODULE__, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    producers = [
      default: [
        module: {OffBroadwayPgmq.Producer, queue: "events"},
        transformer: {__MODULE__, :transform, []}
      ]
    ]

    processors = [default: [concurrency: 2]]

    batchers = [default: [batch_size: 50, batch_timeout: 5_000]]

    {:ok, producers: producers, processors: processors, batchers: batchers}
  end

  @impl true
  def handle_message(_, %Message{data: data} = msg, _ctx) do
    Message.update_data(msg, fn _ -> data end)
  end

  @impl true
  def handle_batch(_, messages, _batcher, _ctx) do
    Enum.each(messages, fn %Message{data: data} ->
      # persist using Repo
      MmoServer.Repo.insert!(data)
    end)

    messages
  end

  def transform(event) do
    %Message{data: event}
  end
end
