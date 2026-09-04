local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Fires when the objective is canceled.
-- Declares no callins: objectives.lua activates it.
return {
	type = 'ObjectiveCanceled',
	parameters = {
		{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
	},
}
