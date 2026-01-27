local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local triggers = {
	addMarkers = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 100,
		},
		actions = { 'addMarkerWithLabel', 'addMarkerWithoutLabel' },
	},

	drawLines = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 200,
		},
		actions = { 'drawLines', 'messageDrawLines' },
	},

	eraseMarker = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 380,
		},
		actions = { 'eraseMarker', 'messageEraseMarker' },
	},
}

local actions = {
	addMarkerWithLabel = {
		type = actionTypes.AddMarker,
		parameters = {
			position = { x = 1900, z = 2200 },
			label = 'This marker will be erased soon.',
		},
	},

	addMarkerWithoutLabel = {
		type = actionTypes.AddMarker,
		parameters = {
			position = { x = 1500, z = 2200 },
		},
	},

	drawLines = {
		type = actionTypes.DrawLines,
		parameters = {
			positions = { { x = 1600, z = 2100 }, { x = 1800, z = 2300 }, { x = 1800, z = 2100 }, { x = 1600, z = 2300 } },
		},
	},

	messageDrawLines = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Let's draw a big X.",
		},
	},

	eraseMarker = {
		type = actionTypes.EraseMarker,
		parameters = {
			position = { x = 1900, z = 2200 },
		},
	},

	messageEraseMarker = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Let's erase a marker.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
