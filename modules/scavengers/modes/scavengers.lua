local ModeDSL = VFS.Include("modules/scavengers/mode_dsl.lua")
local Mode, Scavengers = ModeDSL.Mode, ModeDSL.Scavengers

-- The multiplayer mode, as a preset over the options it always had. Every
-- value here is the default a fresh lobby already shows: the mode's job is to
-- name the shape and field the bot, not to retune the game.
--
-- Difficulty and endless stay open — they are the two choices a lobby is
-- actually there to make.
return Mode("Scavengers")
	.Desc("Hold out against the scavenger swarm, then kill the boss.")
	.Bot("ScavengersAI")
	.Difficulty(Scavengers.Horde, "normal").Unlocked()
	.Boss(Scavengers.Horde, 1)
	.Grace(Scavengers.Horde, 1.0)
	.Pace(Scavengers.Horde, 1.0, 1.0)
	.Placement(Scavengers.Horde, "initialbox")
	.Endless(Scavengers.Horde, false).Unlocked()
