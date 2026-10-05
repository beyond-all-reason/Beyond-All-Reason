local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function startCutscene(cutsceneID)
	GG['MissionAPI'].Modules.Cutscenes.StartCutscene(cutsceneID)
end

return {
	{
		type = 'StartCutscene',
		parameters = {
			{ name = 'cutsceneID', required = true, type = ParameterTypes.CutsceneID },
		},
		actionFunction = startCutscene,
	}
}
