defmodule MmoServer.CooldownSystem do
  @moduledoc false

  @spec check_and_set(term(), String.t(), non_neg_integer()) :: :ok | {:error, term()}
  def check_and_set(player_id, name, cooldown) do
    skill = %MmoServer.Skill{name: name, cooldown: cooldown}

    GenServer.call({:via, Horde.Registry, {PlayerRegistry, player_id}}, {:use_skill, skill})
  catch
    :exit, _ -> {:error, :player_offline}
  end
end

