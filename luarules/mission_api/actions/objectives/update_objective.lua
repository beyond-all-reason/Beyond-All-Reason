local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function updateObjective(objectiveID)
	GG['MissionAPI'].Modules.Objectives.UpdateObjective(objectiveID)
end

return {
	{
		type = 'UpdateObjective',
		parameters = {
			{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
		},
		actionFunction = updateObjective,
	}
}
