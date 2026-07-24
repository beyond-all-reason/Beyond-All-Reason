local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function updateObjective(objectiveID, completed, textKey)
	local objective = GG['MissionAPI'].Objectives[objectiveID]

	if objective.completed then return end

	if textKey then
		objective.textKey = textKey
	end

	if completed ~= nil then
		objective.completed = completed
	elseif textKey == nil then
		objective.progress = (objective.progress or 0) + 1
		objective.completed = objective.amount == nil or objective.progress >= objective.amount
	end

	local objectives = GG['MissionAPI'].Modules.Objectives
	objectives.TryAdvanceStage(objective)
	objectives.EchoObjectiveUpdate(objectiveID, objective)
end

return {
	{
		type = 'UpdateObjective',
		parameters = {
			{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
			{ name = 'completed', required = false, type = ParameterTypes.Boolean },
			{ name = 'textKey', required = false, type = ParameterTypes.String },
		},
		actionFunction = updateObjective,
	}
}
