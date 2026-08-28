local ModeDSL = VFS.Include("modules/scavengers/mode_dsl.lua") ---@type ScavengersModeDSL
local Mode, Scavengers = ModeDSL.Mode, ModeDSL.Scavengers

-- stylua: ignore
return Mode("Scavengers")
	.Desc("Hold out against the scavenger swarm, then kill the boss.")
	.Bot("ScavengersAI")
	.Ranked(false).Locked()
	.Difficulty(Scavengers.Horde, "normal")
	.Boss(Scavengers.Horde, 1)
	.Grace(Scavengers.Horde, 1.0)
	.Pace(Scavengers.Horde, 1.0, 1.0)
	.Placement(Scavengers.Horde, "initialbox").Locked()
	.Endless(Scavengers.Horde, false)
