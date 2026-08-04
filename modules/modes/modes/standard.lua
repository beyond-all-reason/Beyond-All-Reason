local ModeDSL = VFS.Include("modules/modes/mode_dsl.lua") ---@type GameModeDSL
local Mode = ModeDSL.Mode

-- stylua: ignore
return Mode("Standard")
	.Desc("An ordinary game.")
	.Ranked()
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
	.EnemyTransporting("notcoms")
	.Restrictions()
