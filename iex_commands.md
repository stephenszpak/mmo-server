MmoServer.Player.set_class("jaina", "void_vlogger")
MmoServer.SkillSystem.use_skill("jaina", "Echo Chamber", "wolf_1")
MmoServer.SkillSystem.use_skill("jaina", "Echo Chamber", "wolf_1") # should fail if on cooldown

MmoServer.NPC.get_status("wolf_36") # :alive or :dead
MmoServer.NPC.get_hp("wolf_1")

# Subscribing to combat logs (optional)
Phoenix.PubSub.subscribe(MmoServer.PubSub, "combat:log")

# View player's current cooldown state (if accessible)
:sys.get_state({:via, Horde.Registry, {PlayerRegistry, "jaina"}})

:sys.get_state({:via, Horde.Registry, {NPCRegistry, {:npc, "wolf_1"}}})




## Some combat commands
# Set class + use a debuff skill
MmoServer.Player.set_class("jaina", "void_vlogger")
MmoServer.SkillSystem.use_skill("jaina", "Haul of Horrors", "wolf_1")

# Check NPC state for debuffs
:sys.get_state({:via, Horde.Registry, {NPCRegistry, {:npc, "wolf_1"}}})

# Use an AoE skill on a pack
MmoServer.SkillSystem.use_skill("jaina", "Echo Chamber", "wolf_2")

# Verify AoE effects hit all nearby
MmoServer.NPC.get_hp("wolf_1")
MmoServer.NPC.get_hp("wolf_2")
MmoServer.NPC.get_hp("wolf_3")

