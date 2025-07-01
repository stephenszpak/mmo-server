defmodule MmoServer.PersistenceWorkerTest do
  use MmoServer.DataCase, async: true

  test "batch flush" do
    {:ok, pid} = MmoServer.PersistenceWorker.start_link([])
    msg = %Broadway.Message{data: %MmoServer.Schemas.User{}}
    assert [^msg] = MmoServer.PersistenceWorker.handle_batch(:default, [msg], :default, %{})
    GenServer.stop(pid)
  end
end
