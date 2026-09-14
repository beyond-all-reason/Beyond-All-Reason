local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {
	addMarkers = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 2,
		},
		actions = { 'addMarkerToRemove', 'addMarkerToKeep', 'messageAddMarkers' },
	},

	drawLines = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 6,
		},
		actions = { 'drawLines', 'messageDrawLines' },
	},

	removeMarker = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 9,
		},
		actions = { 'removeMarker', 'messageRemoveMarker' },
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
	addMarkerToRemove = {
		type = actionTypes.AddMapMarker,
		parameters = {
			markerName = 'markerToRemove',
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
			message = 'Two markers: a labelled one to remove by name, a bare one to leave until the end.',
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

	removeMarker = {
		type = actionTypes.RemoveMapMarker,
		parameters = {
			markerName = 'markerToRemove',
		},
	},

	messageRemoveMarker = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Let's remove one marker by name.",
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
