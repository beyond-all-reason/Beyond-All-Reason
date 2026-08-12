local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Objectives normally complete through their own condition. This action lets a
-- mission complete or re-word one directly; completion logic itself lives in the
-- objectives module so there is a single engine.
local function updateObjective(objectiveID, completed, textKey)
	GG['MissionAPI'].Modules.Objectives.Update(objectiveID, completed, textKey)
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
