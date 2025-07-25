defmodule MmoServer.SkillMetadata do
  @moduledoc """
  Helper for loading and querying skill data defined in
  `class_details.json`.
  """

  @json_path Path.join([:code.priv_dir(:mmo_server), "repo", "class_details.json"])

  @skills (
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

  @doc "Return all skills across every class as a flat list"
  def get_all_skills do
    skills()
    |> Enum.flat_map(fn class -> Map.get(class, "skills", []) end)
  end

  @doc "Return the skills for the given class. Accepts the display name or slug."
  def get_class_skills(class_name) do
    slug = slugify(class_name)

    skills()
    |> Enum.find_value([], fn class ->
      if slugify(class["name"]) == slug do
        Map.get(class, "skills", [])
      end
    end)
  end

  @doc "Find a skill by its name"
  def get_skill_by_name(name) do
    get_all_skills()
    |> Enum.find(fn skill -> skill["name"] == name end)
  end

  @doc false
  # Reloads skills from disk at runtime. Useful for development.
  def reload do
    path = Path.expand("../../priv/repo/class_details.json", __DIR__)
    Application.put_env(:mmo_server, __MODULE__, load_file(path))
  end

  defp skills do
    Application.get_env(:mmo_server, __MODULE__, @skills)
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end
end
