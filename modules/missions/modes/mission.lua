local ModeDSL = VFS.Include("modules/missions/lib/mode_dsl.lua")
local Mode, Match = ModeDSL.Mode, ModeDSL.Match

return Mode("Mission")
	.Desc("Triggers own the verdict; engine elimination never ends the match.")
	.Own(Match.End)
