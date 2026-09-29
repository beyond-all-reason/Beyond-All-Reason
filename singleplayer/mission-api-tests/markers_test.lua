local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {
	addMarkers = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 3,
		},
		actions = { 'addMarkerToRemove', 'addMarkerToKeep', 'messageAddMarkers' },
	},

	drawLines = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 6,
		},
		actions = { 'drawLines', 'drawTriangle', 'messageDrawLines' },
	},

	removeMarker = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 12,
		},
		actions = { 'removeMarker', 'messageRemoveMarker' },
	},

	removeLine = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 15,
		},
		actions = { 'removeBox', 'messageRemoveLine' },
	},

	removeAll = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 18,
		},
		actions = { 'removeAll', 'removeAllLines', 'messageRemoveAll' },
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
			lineName = 'box',
			positions = {
				{ x = 1600, z = 2100 },
				{ x = 1600, z = 2300 },
				{ x = 1800, z = 2300 },
				{ x = 1800, z = 2100 },
				{ x = 1600, z = 2100 },
			},
		},
	},

	drawTriangle = {
		type = actionTypes.DrawLines,
		parameters = {
			lineName = 'triangle',
			positions = {
				{ x = 2300, z = 2100 },
				{ x = 2500, z = 2100 },
				{ x = 2400, z = 2300 },
				{ x = 2300, z = 2100 },
			},
		},
	},

	messageDrawLines = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Let's draw a box and a triangle.",
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

	messageRemoveLine = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Let's remove the box by name, leaving the triangle.",
		},
	},

	removeBox = {
		type = actionTypes.RemoveLine,
		parameters = {
			lineName = 'box',
		},
	},

	removeAll = {
		type = actionTypes.RemoveAllMapMarkers,
	},

	removeAllLines = {
		type = actionTypes.RemoveAllLines,
	},

	messageRemoveAll = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Let's remove every marker and line, including the triangle.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
