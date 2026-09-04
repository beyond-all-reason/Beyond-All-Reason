local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Fires when the objective fails.
-- Declares no callins: objectives.lua activates it.
return {
	type = 'ObjectiveFailed',
	parameters = {
		{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
	},
}
