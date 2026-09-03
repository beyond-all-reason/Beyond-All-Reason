local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Fires when the objective completes.
-- Declares no callins: objectives.lua activates it.
return {
	type = 'ObjectiveCompleted',
	parameters = {
		{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
	},
}
