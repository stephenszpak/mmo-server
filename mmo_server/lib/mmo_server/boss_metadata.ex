defmodule MmoServer.BossMetadata do
  @moduledoc """
  Helper for loading and querying boss definitions from
  `boss.json`.
  """

  @json_path Path.join([:code.priv_dir(:mmo_server), "repo", "boss.json"])

  @bosses (
    case File.read(@json_path) do
      {:ok, json} -> Jason.decode!(json)
      _ -> []
    end
  )

  def load_file(path) do
    case File.read(path) do
      {:ok, json} -> Jason.decode!(json)
      _ -> []
    end
  end

  @spec get_all_bosses() :: list()
  def get_all_bosses, do: bosses()

  @spec get_boss(String.t()) :: map() | nil
  def get_boss(name) do
    Enum.find(bosses(), fn b -> b["name"] == name end)
  end

  @spec random_boss() :: map() | nil
  def random_boss do
    bosses() |> Enum.random()
  end

  @doc false
  def reload do
    path = Path.expand("../../priv/repo/boss.json", __DIR__)
    Application.put_env(:mmo_server, __MODULE__, load_file(path))
  end

  defp bosses do
    Application.get_env(:mmo_server, __MODULE__, @bosses)
  end
end
