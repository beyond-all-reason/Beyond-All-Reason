local ModeDSL = VFS.Include("modules/modes/mode_dsl.lua") ---@type GameModeDSL
local Mode = ModeDSL.Mode

-- The axis's default: an ordinary game, and the inventory of what an
-- ordinary game lets a lobby decide. The panel is a whitelist, so every dial
-- here is a dial a host actually sees — at the lobby's own defaults, open.
-- Pins nothing, fields no bot. Ranked, because this preset IS standard
-- multiplayer and picking it must not cost anyone their rating.
return Mode("Standard")
	.Desc("An ordinary game.")
	.Ranked()
	.End("com").Unlocked()
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
