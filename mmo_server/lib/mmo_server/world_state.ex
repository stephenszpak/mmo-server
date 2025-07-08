defmodule MmoServer.WorldState do
  @moduledoc """
  Persistent world-wide key/value store backed by the database.
  All values are cached in ETS for fast access and any change
  is broadcast on the `\"world:state\"` PubSub topic.
  """

  use GenServer

  alias MmoServer.Repo
  import Ecto.Query

  defmodule Record do
    use Ecto.Schema
    @primary_key {:key, :string, autogenerate: false}
    schema "world_state" do
      field :value, :map
      timestamps()
    end
  end

  @table :world_state_cache

  ## Client API

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @spec get(String.t()) :: any()
  def get(key) do
    case :ets.lookup(@table, key) do
      [{^key, value}] -> value
      _ -> nil
    end
  end

  @spec all() :: map()
  def all do
    :ets.tab2list(@table)
    |> Map.new()
  end

  @spec put(String.t(), any()) :: :ok
  def put(key, value) do
    GenServer.call(__MODULE__, {:put, key, value})
  end

  @spec delete(String.t()) :: :ok
  def delete(key) do
    GenServer.call(__MODULE__, {:delete, key})
  end

  ## GenServer callbacks

  @impl true
  def init(_state) do
    :ets.new(@table, [:named_table, :public, read_concurrency: true])

    Repo.all(from r in Record, select: {r.key, r.value})
    |> Enum.each(fn {k, v} -> :ets.insert(@table, {k, v}) end)

    {:ok, %{}}
  end

  @impl true
  def handle_call({:put, key, value}, _from, state) do
    now = DateTime.utc_now()

    %Record{key: key, value: value, inserted_at: now, updated_at: now}
    |> Repo.insert(
      on_conflict: [set: [value: value, updated_at: now]],
      conflict_target: :key
    )

    :ets.insert(@table, {key, value})
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "world:state", {:world_state_changed, key, value})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete, key}, _from, state) do
    Repo.delete_all(from r in Record, where: r.key == ^key)
    :ets.delete(@table, key)
    Phoenix.PubSub.broadcast(MmoServer.PubSub, "world:state", {:world_state_deleted, key})
    {:reply, :ok, state}
  end
end
