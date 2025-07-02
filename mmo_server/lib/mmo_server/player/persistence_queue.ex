defmodule MmoServer.Player.PersistenceQueue do
  use GenServer

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :queue.new(), name: __MODULE__)
  end

  def enqueue(pid), do: GenServer.cast(__MODULE__, {:enqueue, pid})

  def dequeue_batch(max \\ 10) do
    GenServer.call(__MODULE__, {:dequeue, max})
  end

  @impl true
  def init(q), do: {:ok, q}

  @impl true
  def handle_cast({:enqueue, pid}, q) do
    {:noreply, :queue.in(pid, q)}
  end

  @impl true
  def handle_call({:dequeue, max}, _from, q) do
    {items, q} = do_dequeue(q, max, [])
    {:reply, items, q}
  end

  defp do_dequeue(q, 0, acc), do: {Enum.reverse(acc), q}

  defp do_dequeue(q, n, acc) do
    case :queue.out(q) do
      {{:value, item}, q} -> do_dequeue(q, n - 1, [item | acc])
      {:empty, q} -> {Enum.reverse(acc), q}
    end
  end
end
