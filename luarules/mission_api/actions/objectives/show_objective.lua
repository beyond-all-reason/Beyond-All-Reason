local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function showObjective(objectiveID)
	GG['MissionAPI'].Modules.Objectives.ShowObjective(objectiveID)
end

return {
	{
		type = 'ShowObjective',
		parameters = {
			{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
		},
		actionFunction = showObjective,
	}
}
