local Types = GG['MissionAPI'].Modules.ParameterTypes.Types

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
	name = 'UpdateObjective',
	parameters = {
		{ name = 'objectiveID', required = true, type = Types.ObjectiveID },
		{ name = 'completed', required = false, type = Types.Boolean },
		{ name = 'textKey', required = false, type = Types.String },
	},
	execute = updateObjective,
}
