local ModeDSL = VFS.Include("modules/modes/mode_dsl.lua") ---@type GameModeDSL
local Mode = ModeDSL.Mode

-- The end rule IS the mode, so it locks; the round config and elimination
-- threshold live in Main, stay unclaimed, and so stay open for the host.
return Mode("Territorial Domination")
	.Desc("Teams earn points by capturing territory to stay in the game. At the end of the final round, the team with the most points wins.")
	.Ranked()
	.End("territorial_domination")
