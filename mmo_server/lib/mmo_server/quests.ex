defmodule MmoServer.Quests do
  @moduledoc "Quest acceptance and progress tracking"

  alias MmoServer.{Repo, Quest, QuestProgress}
  @wolf_kill_id "11111111-1111-1111-1111-111111111111"
  @pelt_collect_id "22222222-2222-2222-2222-222222222222"
  def wolf_kill_id, do: @wolf_kill_id
  def pelt_collect_id, do: @pelt_collect_id


  alias MmoServer.Player.Inventory

  @doc """
  Retrieve the progress for the given player and quest.
  Returns `nil` if the quest has not been accepted.
  """
  @spec get_progress(String.t(), Ecto.UUID.t()) :: %{progress: list(), completed: boolean()} | nil
  def get_progress(player_id, quest_id) do
    case Repo.get_by(QuestProgress, player_id: player_id, quest_id: quest_id) do
      nil -> nil
      %QuestProgress{} = prog -> Map.take(prog, [:progress, :completed])
    end
  end

  @spec accept(String.t(), Ecto.UUID.t()) :: {:ok, QuestProgress.t()} | {:error, term()}
  def accept(player_id, quest_id) do
    Repo.transaction(fn ->
      with %Quest{} = quest <- Repo.get(Quest, quest_id),
           nil <- Repo.get_by(QuestProgress, quest_id: quest_id, player_id: player_id) do
        progress = Enum.map(quest.objectives, fn obj -> Map.put(obj, "count", 0) end)

        %QuestProgress{}
        |> QuestProgress.changeset(%{quest_id: quest_id, player_id: player_id, progress: progress, completed: false})
        |> Repo.insert()
      else
        nil -> Repo.rollback(:not_found)
        %QuestProgress{} -> Repo.rollback(:already_accepted)
      end
    end)
  end

  @spec record_progress(String.t(), Ecto.UUID.t(), map()) :: :ok | {:error, term()}
  def record_progress(player_id, quest_id, %{type: type, target: target}) do
    Repo.transaction(fn ->
      with %QuestProgress{} = prog <- Repo.get_by(QuestProgress, quest_id: quest_id, player_id: player_id),
           %Quest{} = quest <- Repo.get(Quest, quest_id),
           false <- prog.completed do
        new_progress =
          Enum.map(prog.progress, fn obj ->
            if obj["type"] == to_string(type) and obj["target"] == target do
              required = find_required(quest, obj)
              current = min(obj["count"] + 1, required)
              Map.put(obj, "count", current)
            else
              obj
            end
          end)

        prog
        |> QuestProgress.changeset(%{progress: new_progress})
        |> Repo.update!()

        check_completion(player_id, quest_id)
        :ok
      else
        _ -> Repo.rollback(:invalid)
      end
    end)
  end

  defp find_required(%Quest{objectives: objectives}, obj) do
    Enum.find_value(objectives, 0, fn q ->
      if q["type"] == obj["type"] and q["target"] == obj["target"], do: q["count"], else: false
    end)
  end

  @spec check_completion(String.t(), Ecto.UUID.t()) :: :ok
  def check_completion(player_id, quest_id) do
    Repo.transaction(fn ->
      with %QuestProgress{} = prog <- Repo.get_by(QuestProgress, quest_id: quest_id, player_id: player_id),
           %Quest{} = quest <- Repo.get(Quest, quest_id),
           false <- prog.completed do
        complete? = objectives_complete?(quest.objectives, prog.progress)

        if complete? do
          prog
          |> QuestProgress.changeset(%{completed: true})
          |> Repo.update!()

          grant_rewards(player_id, quest.rewards)
        end

        :ok
      else
        _ -> :ok
      end
    end)
  end

  defp objectives_complete?(objs, progress) do
    Enum.all?(objs, fn obj ->
      case Enum.find(progress, fn p -> p["type"] == obj["type"] and p["target"] == obj["target"] end) do
        nil -> false
        p -> p["count"] >= obj["count"]
      end
    end)
  end

  @spec grant_rewards(String.t(), list()) :: :ok
  def grant_rewards(player_id, rewards) do
    Enum.each(rewards, fn
      %{"type" => "xp", "amount" => amt} when is_integer(amt) ->
        MmoServer.Player.XP.gain(player_id, amt)

      %{"item" => item} = reward ->
        Inventory.add_item(player_id, %{item: item, quality: Map.get(reward, "quality", "common")})

      _ ->
        :ok
    end)

    :ok
  end
end
