local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {
	addMarkers = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 2,
		},
		actions = { 'addMarkerToErase', 'addMarkerToKeep', 'messageAddMarkers' },
	},

	drawLines = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 6,
		},
		actions = { 'drawLines', 'messageDrawLines' },
	},

	eraseMarker = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 9,
		},
		actions = { 'eraseMarker', 'messageEraseMarker' },
	},

	clearAll = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 12,
		},
		actions = { 'clearAll', 'messageClearAll' },
	},
}

local actions = {
	addMarkerToErase = {
		type = actionTypes.AddMapMarker,
		parameters = {
			markerName = 'markerToErase',
			position = { x = 1900, z = 2200 },
			markerType = 'mapmark',
			label = 'This marker will be erased soon.',
		},
	},

	addMarkerToKeep = {
		type = actionTypes.AddMapMarker,
		parameters = {
			markerName = 'markerToKeep',
			position = { x = 1500, z = 2200 },
		},
	},

	messageAddMarkers = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'Two markers: a labelled one to erase by ID, a bare one to leave until the end.',
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
			name = 'markerToErase',
		},
	},

	messageEraseMarker = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Let's erase one marker by its ID.",
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
