local Types = GG['MissionAPI'].Modules.ParameterTypes.Types

local function changeStage(stageID)
	GG['MissionAPI'].Modules.Objectives.ChangeStage(stageID)
end

return {
	type = 'ChangeStage',
	parameters = {
		{ name = 'stageID', required = true, type = Types.StageID },
	},
	actionFunction = changeStage,
}
