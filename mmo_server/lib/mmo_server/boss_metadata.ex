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

  @spec get_loot_for(String.t()) :: map() | nil
  def get_loot_for(name) do
    case get_boss(name) do
      nil -> nil
      boss -> Map.get(boss, "loot")
    end
  end

  @spec roll_loot(String.t()) :: %{epic: list(), rare: list(), gold: integer()} | nil
  def roll_loot(name) do
    with %{"epic" => epic, "rare" => rare} = loot <- get_loot_for(name) do
      gold_range = Map.get(loot, "gold_range", %{"min" => 0, "max" => 0})
      min_gold = Map.get(gold_range, "min", 0)
      max_gold = Map.get(gold_range, "max", min_gold)

      epic_count = min(length(epic), :rand.uniform(2))
      rare_count = min(length(rare), :rand.uniform(3))

      %{
        epic: Enum.take_random(epic, epic_count),
        rare: Enum.take_random(rare, rare_count),
        gold: min_gold + :rand.uniform(max(max_gold - min_gold + 1, 1)) - 1
      }
    end
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
