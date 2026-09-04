local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function deactivateObjective(objectiveID)
	local objectives = GG['MissionAPI'].Modules.Objectives
	objectives.DeactivateObjective(objectiveID)
	objectives.EchoObjectiveUpdate(objectiveID, GG['MissionAPI'].Objectives[objectiveID]) -- temp
end

return {
	{
		type = 'DeactivateObjective',
		parameters = {
			{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
		},
		actionFunction = deactivateObjective,
	}
}
