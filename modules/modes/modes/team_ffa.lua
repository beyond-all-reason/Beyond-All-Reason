local ModeDSL = VFS.Include("modules/modes/mode_dsl.lua") ---@type GameModeDSL
local Mode = ModeDSL.Mode

-- Several teams, every team for itself. Shuffled boxes are what make it a
-- mode rather than a seating chart: team 1 no longer always starts in box 1.
-- The FFA wreckage manners apply — what a fallen team leaves is fought over.
return Mode("Team FFA")
	.Desc("Several teams, every team for itself. Start boxes are dealt at random, and fallen teams leave wreckage behind.")
	.Ranked()
	.ShuffleStartBoxes(true)
	.Wreckage(true)
