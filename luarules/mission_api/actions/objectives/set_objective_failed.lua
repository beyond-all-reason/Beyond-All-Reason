local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function setObjectiveFailed(objectiveID)
	GG['MissionAPI'].Modules.Objectives.SetObjectiveFailed(objectiveID)
end

return {
	{
		type = 'SetObjectiveFailed',
		parameters = {
			{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
		},
		actionFunction = setObjectiveFailed,
	}
}
