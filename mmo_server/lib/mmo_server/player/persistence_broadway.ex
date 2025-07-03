defmodule MmoServer.Player.PersistenceBroadway do
  use Broadway

  alias MmoServer.{Repo, PlayerPersistence}
  require Logger

  def start_link(opts \\ []) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {Broadway.DummyProducer, []},
        transformer: {__MODULE__, :transform, []}
      ],
      processors: [default: [concurrency: 4]],
      batchers: [db: [batch_size: 100, batch_timeout: 1_000]]
    )
  end

  @impl true
  def handle_message(_, message, _context), do: message

  def push(event), do: Broadway.test_message(__MODULE__, event)

  def transform(event, _opts) do
    event
    |> Broadway.Message.new()
    |> Broadway.Message.put_batcher(:db)
  end

  @impl true
  def handle_batch(:db, messages, _batch_info, _context) do
    rows =
      Enum.map(messages, fn %Broadway.Message{data: attrs} ->
        Map.put(attrs, :updated_at, DateTime.utc_now(:second))
      end)

    Repo.insert_all(
      PlayerPersistence,
      rows,
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: :id
    )

    messages
  end

  @impl true
  def handle_failed(messages, reason, _context) do
    Logger.error("Failed to persist player data: #{inspect(reason)}")
    messages
  end
end
