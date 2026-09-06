local ModeDSL = VFS.Include("modules/game/mode_dsl.lua") ---@type GameModeDSL
local Mode = ModeDSL.Mode
local DeathMode, DraftMode, AnonymousMode = ModeDSL.DeathMode, ModeDSL.DraftMode, ModeDSL.AnonymousMode

-- stylua: ignore
return Mode("Territorial Domination")
	.Desc(
		"Teams earn points by capturing territory to stay in the game. At the end of the final round, the team with the most points wins."
	)
	.Ranked()
	.End(DeathMode.TerritorialDomination).Locked()
	.MaxUnits(2000)
	.Draft(DraftMode.Random)
	.Anonymous(AnonymousMode.Disabled)
	.PausedCommands(true)
	.CustomWidgets(true)
	.UnitControlWidgets(true)
	.FixedAlliances(true)
	.MapDeformation(true)
	.FogOfWar(true)
	.NoRush(0)
	.SlowComTransport(false)
	.EnemyTransporting("notcoms")
	.UnitRestrictions()
