local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function failObjective(objectiveID)
	GG['MissionAPI'].Modules.Objectives.FailObjective(objectiveID)
end

return {
	{
		type = 'FailObjective',
		parameters = {
			{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
		},
		actionFunction = failObjective,
	}
}
