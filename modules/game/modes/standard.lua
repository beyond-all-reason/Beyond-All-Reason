local ModeDSL = VFS.Include("modules/game/mode_dsl.lua") ---@type GameModeDSL
local Mode = ModeDSL.Mode
local DeathMode, DraftMode, AnonymousMode = ModeDSL.DeathMode, ModeDSL.DraftMode, ModeDSL.AnonymousMode

-- stylua: ignore
return Mode("Standard")
	.Desc("An ordinary game: no scripted mission, no PvE swarm.")
	.Ranked()
	.End(DeathMode.Commander)
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
