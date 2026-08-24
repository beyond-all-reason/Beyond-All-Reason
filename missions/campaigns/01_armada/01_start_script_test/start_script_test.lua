local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {
	addMarkerBeginner = {
		type = triggerTypes.TimeElapsed,
		settings = {
			difficulties = { "Beginner" },
		},
		parameters = {
			seconds = 2,
		},
		actions = { 'addMarkerBeginner' },
	},

	addMarkerNormal = {
		type = triggerTypes.TimeElapsed,
		settings = {
			difficulties = { "Normal" },
		},
		parameters = {
			seconds = 2,
		},
		actions = { 'addMarkerNormal' },
	},

	addMarkerHard = {
		type = triggerTypes.TimeElapsed,
		settings = {
			difficulties = { "Hard" },
		},
		parameters = {
			seconds = 2,
		},
		actions = { 'addMarkerHard' },
	},
}

local actions = {
	addMarkerBeginner = {
		type = actionTypes.AddMarker,
		parameters = {
			position = { x = 700, z = 900 },
			label = 'Difficulty: Beginner',
		},
	},

	addMarkerNormal = {
		type = actionTypes.AddMarker,
		parameters = {
			position = { x = 800, z = 900 },
			label = 'Difficulty: Normal',
		},
	},

	addMarkerHard = {
		type = actionTypes.AddMarker,
		parameters = {
			position = { x = 900, z = 900 },
			label = 'Difficulty: Hard',
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
