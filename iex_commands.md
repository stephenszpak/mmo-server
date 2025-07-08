MmoServer.Player.set_class("jaina", "void_vlogger")
MmoServer.SkillSystem.use_skill("jaina", "Echo Chamber", "wolf_36")
MmoServer.SkillSystem.use_skill("jaina", "Echo Chamber", "wolf_1") # should fail if on cooldown

MmoServer.NPC.get_status("wolf_36") # :alive or :dead
MmoServer.NPC.get_hp("wolf_36")

# Subscribing to combat logs (optional)
Phoenix.PubSub.subscribe(MmoServer.PubSub, "combat:log")

# View player's current cooldown state (if accessible)
:sys.get_state({:via, Horde.Registry, {PlayerRegistry, "jaina"}})

