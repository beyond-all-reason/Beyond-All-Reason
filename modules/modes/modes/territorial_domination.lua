local ModeDSL = VFS.Include("modules/modes/mode_dsl.lua") ---@type GameModeDSL
local Mode = ModeDSL.Mode

-- The end rule IS the mode, so it locks — and it brings its own dials: the
-- round table and the elimination threshold ride on the territorial end
-- rule, exposed open for the host, shown in no other mode.
return Mode("Territorial Domination")
	.Desc("Teams earn points by capturing territory to stay in the game. At the end of the final round, the team with the most points wins.")
	.Ranked()
	.End("territorial_domination")
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
