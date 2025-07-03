defmodule MmoServer.Player.PersistenceBroadway do
  use Broadway

  alias MmoServer.Player.PersistenceQueue
  alias MmoServer.PlayerPersistence
  alias MmoServer.PostgresPool

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
    # Store timestamps using NaiveDateTime so they match the `timestamps/0`
    # columns defined in the migrations. Using DateTime would cause a type
    # mismatch and silently prevent writes from succeeding.
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    entries =
      Enum.map(messages, fn %Broadway.Message{data: attrs} ->
        Map.put(attrs, :inserted_at, now)
        |> Map.put(:updated_at, now)
      end)

    if entries != [] do
      values_sql =
        Enum.with_index(entries, 1)
        |> Enum.map(fn {_, idx} ->
          placeholders = Enum.map_join(0..8, ",", fn i -> "$#{idx * 9 - 9 + i + 1}" end)
          "(" <> placeholders <> ")"
        end)
        |> Enum.join(",")

      params =
        Enum.flat_map(entries, fn e ->
          [e.id, e.zone_id, e.x, e.y, e.z, e.hp, e.status, e.inserted_at, e.updated_at]
        end)

      sql = """
      INSERT INTO players (id, zone_id, x, y, z, hp, status, inserted_at, updated_at)
      VALUES #{values_sql}
      ON CONFLICT (id) DO UPDATE SET
        zone_id = EXCLUDED.zone_id,
        x = EXCLUDED.x,
        y = EXCLUDED.y,
        z = EXCLUDED.z,
        hp = EXCLUDED.hp,
        status = EXCLUDED.status,
        updated_at = EXCLUDED.updated_at
      """

      MmoServer.PostgresPool.query(sql, params)
    end

    {:noreply, messages, state}
  end
end
