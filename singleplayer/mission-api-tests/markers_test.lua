local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local triggers = {
	addMarkers = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 60,
		},
		actions = { 'addMarkerWithLabel', 'addMarkerWithoutLabel' },
	},

	drawLines = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 180,
		},
		actions = { 'drawLines', 'messageDrawLines' },
	},

	eraseMarker = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 270,
		},
		actions = { 'eraseMarker', 'messageEraseMarker' },
	},

	clearAll = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 360,
		},
		actions = { 'clearAll', 'messageClearAll' },
	},
}

local actions = {
	addMarkerWithLabel = {
		type = actionTypes.AddMarker,
		parameters = {
			position = { x = 1900, z = 2200 },
			label = 'This marker will be erased soon.',
			name = 'markerWithLabel',
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
			positions = {
				{ x = 1600, z = 2100 },
				{ x = 1600, z = 2300 },
				{ x = 1800, z = 2300 },
				{ x = 1800, z = 2100 },
				{ x = 1600, z = 2100 },
			},
		},
	},

	messageDrawLines = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Let's draw a box.",
		},
	},

	eraseMarker = {
		type = actionTypes.EraseMarker,
		parameters = {
			name = 'markerWithLabel',
		},
	},

	messageEraseMarker = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Let's erase a marker.",
		},
	},

	clearAll = {
		type = actionTypes.ClearAllMarkers,
	},

	messageClearAll = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Let's clear all markers.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
