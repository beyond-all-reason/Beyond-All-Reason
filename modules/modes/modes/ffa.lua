local ModeDSL = VFS.Include("modules/modes/mode_dsl.lua") ---@type GameModeDSL
local Mode = ModeDSL.Mode

-- stylua: ignore
return Mode("FFA")
	.Desc(
		"Free for all: every player for themselves. Losing your commander resigns you, and the fallen leave wreckage behind."
	)
	.Ranked()
	.End("own_com")
	.Wreckage(true).Locked()
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
