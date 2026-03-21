local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local lobbyData = {
	missionId = "markers_test",
	title = "Markers Test",
	description = "Lorem Ipsum ...",
	unlocked = true,
}

local startScript = {
	mapName = "Quicksilver Remake 1.24",
	startPosType = 'chooseBeforeGame', -- lobby maps this: fixed = 0, random = 1, chooseInGame = 2, chooseBeforeGame = 3
	disableFactionPicker = true, -- should this always be true, so faction can only be chosen in the lobby? or only in game?
	disableInitialCommanderSpawn = true,
	modOptions = {
		deathMode = 'builders',
	},
	allyTeams = {
		thePlayerAllyTeam = {
			teams = {
				thePlayerTeam = { -- teamName must be unique across all ally teams
					name = "PlayerPawns", -- in-game name, player name rules apply, so no spaces etc...
					Side = 'Cortex',
					StartPosX = 700, -- used when startPosType is 'chooseBeforeGame'
					StartPosZ = 700,
					ai = nil, -- is a player
				},
			},
		},
		theEnemyAllyTeam = {
			teams = {
				theEnemyTeam = {
					name = "Mission Bots",
					Side = 'Armada',
					StartPosX = 3000,
					StartPosZ = 2400,
					IncomeMultiplier = 1.5,
					ai = "SimpleAI", -- lobby passes this as shortName
				},
			}
		},
	},
}

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
	LobbyData = lobbyData,
	StartScript = startScript,
	Triggers = triggers,
	Actions = actions,
}
