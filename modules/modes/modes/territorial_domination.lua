local ModeDSL = VFS.Include("modules/modes/mode_dsl.lua") ---@type GameModeDSL
local Mode = ModeDSL.Mode

-- stylua: ignore
return Mode("Territorial Domination")
	.Desc(
		"Teams earn points by capturing territory to stay in the game. At the end of the final round, the team with the most points wins."
	)
	.Ranked()
	.End("territorial_domination").Locked()
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
	.EnemyTransporting("notcoms")
	.Restrictions()
