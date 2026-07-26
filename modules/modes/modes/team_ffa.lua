local ModeDSL = VFS.Include("modules/modes/mode_dsl.lua") ---@type GameModeDSL
local Mode = ModeDSL.Mode

-- stylua: ignore
return Mode("Team FFA")
	.Desc("Several teams, every team for itself. Start boxes are dealt at random, and fallen teams leave wreckage behind.")
	.Ranked()
	.ShuffleStartBoxes(true).Locked()
	.Wreckage(true).Locked()
	.End("com")
	.MaxUnits(2000)
	.Draft("random")
	.Anonymous("disabled")
	.PausedCommands(true)
	.CustomWidgets(true)
	.UnitControlWidgets(true)
	.FixedAlliances(true)
	.MapDeformation(true)
	.FogOfWar(true)
	.NoRush(0)
	.SlowComTransport(false)
	.Restrictions()
