local Types = GG['MissionAPI'].Modules.ParameterTypes.Types

local function changeStage(stageID)
	GG['MissionAPI'].Modules.Objectives.ChangeStage(stageID)
end

return {
	name = 'ChangeStage',
	parameters = {
		{ name = 'stageID', required = true, type = Types.StageID },
	},
	execute = changeStage,
}
