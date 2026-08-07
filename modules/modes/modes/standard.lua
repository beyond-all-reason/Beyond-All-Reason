local ModeDSL = VFS.Include("modules/modes/mode_dsl.lua") ---@type GameModeDSL
local Mode = ModeDSL.Mode

-- The axis's default: an ordinary game. Pins nothing, fields no bot. Ranked,
-- because this preset IS standard multiplayer and picking it must not cost
-- anyone their rating.
return Mode("Standard")
	.Desc("An ordinary game: no scripted mission, no PvE swarm.")
	.Ranked()
