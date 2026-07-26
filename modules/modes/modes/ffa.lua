local ModeDSL = VFS.Include("modules/modes/mode_dsl.lua") ---@type GameModeDSL
local Mode = ModeDSL.Mode

-- Every player for themselves: Standard's dials with the FFA table manners.
-- Your commander falling ends you (open — some tables play it differently),
-- and the fallen leave their wrecks to be fought over (pinned; it is what
-- makes FFA readable).
return Mode("FFA")
	.Desc("Free for all: every player for themselves. Losing your commander resigns you, and the fallen leave wreckage behind.")
	.Ranked()
	.End("own_com").Unlocked()
	.Wreckage(true)
	.MaxUnits(2000)
	.Draft("random").Unlocked()
	.Anonymous("disabled").Unlocked()
	.PausedCommands(true).Unlocked()
	.CustomWidgets(true).Unlocked()
	.UnitControlWidgets(true).Unlocked()
	.FixedAlliances(true).Unlocked()
	.MapDeformation(true).Unlocked()
	.FogOfWar(true).Unlocked()
	.NoRush(0)
	.SlowComTransport(false).Unlocked()
	.Restrictions()
