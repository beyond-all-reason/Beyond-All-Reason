-- Ends the cutscene and unpauses the game (if a video).
-- Works even when the cutscene is not skippable.

local function skipCutscene()
	GG['MissionAPI'].Modules.Cutscenes.SkipCutscene()
end

return {
	{
		type = 'SkipCutscene',
		parameters = {},
		actionFunction = skipCutscene,
	}
}
