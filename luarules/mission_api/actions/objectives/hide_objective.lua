local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function hideObjective(objectiveID)
	GG['MissionAPI'].Modules.Objectives.HideObjective(objectiveID)
end

return {
	{
		type = 'HideObjective',
		parameters = {
			{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
		},
		actionFunction = hideObjective,
	}
}
