local ModeDSL = VFS.Include("modules/modes/mode_dsl.lua") ---@type GameModeDSL
local Mode = ModeDSL.Mode

-- Several teams, every team for itself: Standard's dials, with the boxes
-- dealt at random (pinned — team 1 always getting box 1 is the seating
-- chart this mode exists to shred) and the FFA wreckage manners.
return Mode("Team FFA")
	.Desc("Several teams, every team for itself. Start boxes are dealt at random, and fallen teams leave wreckage behind.")
	.Ranked()
	.ShuffleStartBoxes(true)
	.Wreckage(true)
	.End("com")
	.Unlocked()
	.MaxUnits(2000)
	.Draft("random")
	.Unlocked()
	.Anonymous("disabled")
	.Unlocked()
	.PausedCommands(true)
	.Unlocked()
	.CustomWidgets(true)
	.Unlocked()
	.UnitControlWidgets(true)
	.Unlocked()
	.FixedAlliances(true)
	.Unlocked()
	.MapDeformation(true)
	.Unlocked()
	.FogOfWar(true)
	.Unlocked()
	.NoRush(0)
	.SlowComTransport(false)
	.Unlocked()
	.Restrictions()
