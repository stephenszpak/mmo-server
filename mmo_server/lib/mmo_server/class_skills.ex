defmodule MmoServer.ClassSkills do
  @moduledoc """
  Load and query class skill metadata from JSON.
  """

  @json_path Path.join([:code.priv_dir(:mmo_server), "repo", "class_skills_with_lore.json"])

  @classes (
    case File.read(@json_path) do
      {:ok, json} -> Jason.decode!(json)
      _ -> []
    end
  )

  @doc false
  def load_file(path) do
    case File.read(path) do
      {:ok, json} -> Jason.decode!(json)
      _ -> []
    end
  end

  @doc "Reload metadata at runtime"
  def reload(path \\ @json_path) do
    Application.put_env(:mmo_server, __MODULE__, load_file(path))
  end

  defp classes do
    Application.get_env(:mmo_server, __MODULE__, @classes)
  end

  @doc "Get all skills for a class by name or slug"
  def get_skills_for_class(class_name) do
    slug = slugify(class_name)

    classes()
    |> Enum.find_value([], fn class ->
      if slugify(class["name"]) == slug, do: class["skills"] || []
    end)
  end

  @doc "Get a specific skill by class and name"
  def get_skill(class_name, skill_name) do
    get_skills_for_class(class_name)
    |> Enum.find(fn s -> s["name"] == skill_name end)
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end
end
