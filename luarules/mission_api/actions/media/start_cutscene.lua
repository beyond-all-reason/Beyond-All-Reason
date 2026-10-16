local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function startCutscene(cutsceneID, skippable)
	GG['MissionAPI'].Modules.Cutscenes.StartCutscene(cutsceneID, skippable)
end

return {
	{
		type = 'StartCutscene',
		parameters = {
			{ name = 'cutsceneID', required = true,  type = ParameterTypes.CutsceneID },
			{ name = 'skippable',  required = false, type = ParameterTypes.Boolean },
		},
		actionFunction = startCutscene,
	}
}
