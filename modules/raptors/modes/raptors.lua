local ModeDSL = VFS.Include("modules/raptors/mode_dsl.lua") ---@type RaptorsModeDSL
local Mode, Raptors = ModeDSL.Mode, ModeDSL.Raptors

-- The multiplayer mode, as a preset over the options it always had. Every
-- value here is the default a fresh lobby already shows: the mode's job is to
-- name the shape and field the bot, not to retune the game.
--
-- Difficulty and endless stay open — they are the two choices a lobby is
-- actually there to make — and the first-waves boost rides along as the
-- open dial it always was; the panel is a whitelist, so an unclaimed dial
-- is an invisible one.
return Mode("Raptors")
	.Desc("Hold out against the raptor swarm, then kill the queen.")
	.Bot("RaptorsAI")
	.Ranked(false)
	.Locked()
	.Difficulty(Raptors.Swarm, "normal")
	.Unlocked()
	.Boss(Raptors.Swarm, 1)
	.Grace(Raptors.Swarm, 1.0)
	.Pace(Raptors.Swarm, 1.0, 1.0)
	.Placement(Raptors.Swarm, "initialbox")
	.Endless(Raptors.Swarm, false)
	.Unlocked()
	.Boost(Raptors.Swarm, 1)
