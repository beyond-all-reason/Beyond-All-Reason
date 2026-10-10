local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function cancelObjective(objectiveID)
	GG['MissionAPI'].Modules.Objectives.CancelObjective(objectiveID)
end

return {
	{
		type = 'CancelObjective',
		parameters = {
			{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
		},
		actionFunction = cancelObjective,
	}
}
