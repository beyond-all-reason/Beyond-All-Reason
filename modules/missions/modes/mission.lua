local ModeDSL = VFS.Include("modules/missions/lib/mode_dsl.lua") ---@type MissionsModeDSL
local Mode, Match = ModeDSL.Mode, ModeDSL.Match

return Mode("Mission")
	.Desc("The mission decides when it is won or lost, so losing your units does not end the match. Every unit is loaded, because a mission can use anything.")
	.Own(Match.End)
	.Loads(Match.EveryUnitDef)
