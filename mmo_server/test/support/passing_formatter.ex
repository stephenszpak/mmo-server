defmodule MmoServer.PassingFormatter do
  use GenServer

  def init(opts) do
    {:ok, opts}
  end

  def handle_cast({:test_finished, %ExUnit.Test{name: name, state: nil}}, opts) do
    IO.puts("Test passed: #{name}")
    {:noreply, opts}
  end

  def handle_cast(_, opts), do: {:noreply, opts}
end
