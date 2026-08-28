local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Fires when a single watched objective is completed.
-- Declares no callins; the objectives module dispatches it (see objectives.lua).

return {
	type = 'ObjectiveCompleted',
	parameters = {
		{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
	},
}
