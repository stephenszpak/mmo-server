defmodule MmoServer.UnityHash do
  @moduledoc """
  Utilities for working with Unity's stable 32-bit hash used by the
  client to identify players.
  """

  use Bitwise

  @initial 2_166_136_261
  @prime 16_777_619
  @mask 0xFFFF_FFFF

  @doc """
  Calculate the 32-bit FNV-1a hash for the given string.
  Returns an unsigned integer within `0..0xFFFFFFFF`.
  """
  @spec hash(String.t()) :: non_neg_integer()
  def hash(string) when is_binary(string) do
    string
    |> :binary.bin_to_list()
    |> Enum.reduce(@initial, fn b, acc ->
      acc
      |> bxor(b)
      |> Kernel.*(@prime)
      |> band(@mask)
    end)
  end

  @doc """
  Attempt to find a player_id registered in `PlayerRegistry` that
  corresponds to the given hashed identifier. Returns `nil` if no match
  is found.
  """
  @spec lookup_player_id(non_neg_integer()) :: String.t() | nil
  def lookup_player_id(player_hash) do
    Horde.Registry.select(PlayerRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.filter(&is_binary/1)
    |> Enum.find(fn id -> hash(id) == player_hash end)
  end
end
