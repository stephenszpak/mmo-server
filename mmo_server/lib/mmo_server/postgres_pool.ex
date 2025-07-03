defmodule MmoServer.PostgresPool do
  @behaviour NimblePool

  def child_spec(opts) do
    {NimblePool, Keyword.merge([name: __MODULE__, worker: {__MODULE__, opts}], opts)}
  end

  def start_link(opts \\ []) do
    opts = if opts == [], do: Application.fetch_env!(:mmo_server, __MODULE__), else: opts
    NimblePool.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init_pool(opts), do: {:ok, opts}

  @impl true
  def init_worker(opts) do
    {:ok, conn} = NimblePostgres.connect(opts)
    {:ok, conn, opts}
  end

  @impl true
  def handle_checkout(:checkout, _from, conn, state) do
    {:ok, conn, conn, state}
  end

  @impl true
  def handle_checkin(_client_state, _from, conn, state) do
    {:ok, conn, state}
  end

  @impl true
  def terminate_worker(_reason, conn, state) do
    NimblePostgres.disconnect(conn)
    {:ok, state}
  end

  def query(sql, params \\ []) do
    NimblePool.checkout!(__MODULE__, :checkout, fn _from, conn ->
      NimblePostgres.query(conn, sql, params)
    end)
  end
end
