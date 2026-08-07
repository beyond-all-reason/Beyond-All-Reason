local ModeDSL = VFS.Include("modules/raptors/mode_dsl.lua") ---@type RaptorsModeDSL
local Mode, Raptors = ModeDSL.Mode, ModeDSL.Raptors

-- stylua: ignore
return Mode("Raptors")
	.Desc("Hold out against the raptor swarm, then kill the queen.")
	.Bot("RaptorsAI")
	.Ranked(false).Locked()
	.Difficulty(Raptors.Swarm, "normal")
	.Boss(Raptors.Swarm, 1)
	.Grace(Raptors.Swarm, 1.0)
	.Pace(Raptors.Swarm, 1.0, 1.0)
	.Placement(Raptors.Swarm, "initialbox").Locked()
	.Endless(Raptors.Swarm, false)
	.Boost(Raptors.Swarm, 1)
