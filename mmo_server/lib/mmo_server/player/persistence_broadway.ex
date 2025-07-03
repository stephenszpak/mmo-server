defmodule MmoServer.Player.PersistenceBroadway do
  use Broadway

  alias MmoServer.Player.PersistenceQueue
  alias MmoServer.PlayerPersistence
  alias MmoServer.Repo

  def start_link(_opts \\ []) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [module: {__MODULE__.Producer, []}, concurrency: 1],
      processors: [default: [concurrency: 1]],
      # Persist updates quickly so interactive sessions see changes almost
      # immediately. The previous timeout of 1 second caused noticeable delays
      # before player state was written to the database.
      batchers: [default: [batch_size: 50, batch_timeout: 100]]
    )
  end

  defmodule __MODULE__.Producer do
    use GenStage

    def start_link(_opts) do
      GenStage.start_link(__MODULE__, :ok)
    end

    # Broadway injects configuration into the options passed to the producer.
    # Accept any argument here to avoid a function clause error during startup.
    def init(_opts), do: {:producer, :ok}

    def handle_demand(demand, state) when demand > 0 do
      events = PersistenceQueue.dequeue_batch(demand)
      {:noreply, events, state}
    end
  end

  @impl true
  def handle_message(_, pid, _) do
    state = :sys.get_state(pid)
    {x, y, z} = state.pos

    %Broadway.Message{
      acknowledger: Broadway.NoopAcknowledger.init(),
      data: %{
        id: state.id,
        zone_id: state.zone_id,
        x: x,
        y: y,
        z: z,
        hp: state.hp,
        status: Atom.to_string(state.status)
      }
    }
  end

  @impl true
  def handle_batch(:default, messages, _batch_info, state) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      Enum.map(messages, fn %Broadway.Message{data: attrs} ->
        Map.put(attrs, :inserted_at, now)
        |> Map.put(:updated_at, now)
      end)

    if entries != [] do
      Repo.insert_all(PlayerPersistence, entries,
        on_conflict: {:replace, [:zone_id, :x, :y, :z, :hp, :status, :updated_at]},
        conflict_target: :id
      )
    end

    {:noreply, messages, state}
  end
end
