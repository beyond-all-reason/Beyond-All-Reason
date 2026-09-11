local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function activateObjective(objectiveID)
	local objectives = GG['MissionAPI'].Modules.Objectives
	objectives.ActivateObjective(objectiveID)
	objectives.EchoObjectiveUpdate(objectiveID, GG['MissionAPI'].Objectives[objectiveID]) -- temp
end

return {
	{
		type = 'ActivateObjective',
		parameters = {
			{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
		},
		actionFunction = activateObjective,
	}
}
