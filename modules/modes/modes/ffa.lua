local ModeDSL = VFS.Include("modules/modes/mode_dsl.lua") ---@type GameModeDSL
local Mode = ModeDSL.Mode

-- Every player for themselves. The dials are Standard's; the defaults are
-- the FFA table manners: your commander falling ends you, and the fallen
-- leave their wrecks to be fought over. The end rule stays open — some
-- tables play it differently — the wreckage rule is what makes FFA readable
-- and stays pinned.
return Mode("FFA")
	.Desc("Free for all: every player for themselves. Losing your commander resigns you, and the fallen leave wreckage behind.")
	.Ranked()
	.End("own_com").Unlocked()
	.Wreckage(true)
