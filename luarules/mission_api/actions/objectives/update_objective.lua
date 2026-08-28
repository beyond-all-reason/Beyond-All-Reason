local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function updateObjective(objectiveID, completed, textKey)
	local objective = GG['MissionAPI'].Objectives[objectiveID]

	if objective.completed then return end

	if textKey then
		objective.textKey = textKey
	end

	local objectives = GG["MissionAPI"].Modules.Objectives
	if completed ~= nil then
		objectives.SetObjectiveCompleted(objectiveID, completed)
	elseif textKey == nil then
		objectives.IncrementObjectiveProgress(objectiveID)
	else
		objectives.EchoObjectiveUpdate(objectiveID, objective)
	end
end

return {
	{
		type = 'UpdateObjective',
		parameters = {
			{ name = 'objectiveID', required = true,  type = ParameterTypes.ObjectiveID },
			{ name = 'completed',   required = false, type = ParameterTypes.Boolean },
			{ name = 'textKey',     required = false, type = ParameterTypes.String },
		},
		actionFunction = updateObjective,
	}
}
