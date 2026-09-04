local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function updateObjective(objectiveID)
	local objective = GG['MissionAPI'].Objectives[objectiveID]

	if objective.completed then return end

	objective.progress = (objective.progress or 0) + 1

	local objectives = GG['MissionAPI'].Modules.Objectives
	if objective.amount == nil or objective.progress >= objective.amount then
		objectives.CompleteObjective(objectiveID)
	else
		objectives.EchoObjectiveUpdate(objectiveID, objective)
	end
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
