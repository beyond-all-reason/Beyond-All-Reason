local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

-- display in lobby, inspired by https://www.figma.com/design/XmKdpNvdclGEVwW6c2EaKH/BAR_new-client?node-id=228-2&p=f&t=m6SWIi6tC92CRpZi-0
local lobbyData = {
	missionId = "1",
	title = "Mission 1: The Stars are Falling",
	description = "Lorem Ipsum ...",
	startPos = { x = 0.25, y = 0.25 }, -- marker on map in lobby to indicate the player's starting position
	image = "scenario002.jpg",
	unlocked = true, -- dynamic data, should not be here, but in lobby state - this is just for testing purposes

	-- the rest are not used for now, but are in the Figma
	alliesPresent = { "Fortified Outpost", "Reinforcements en route" },
	objectives = { "Build a base.", "Obliterate their nukes." },
	knownHostiles = { "Raptors - extremely likely", "Unidentified raiders - inbound" },
	newUnits = {
		armflash = "Blitz - a fast assault tank.",
		armcv = "Construction Vehicle - builds structures.",
	},
}

local startScript = {
	mapName = "Fallendell V4", -- as displayed in the map selection screen. Lobby replaces spaces with underscores
	startPosType = 'chooseBeforeGame', -- lobby maps this: fixed = 0, random = 1, chooseInGame = 2, chooseBeforeGame = 3
	disableFactionPicker = true,
	players = { min = 1, max = 4 },
	unitLimits = {
		armavp = 0, -- set to 0 to disable the unit
		coravp = 5,
	},
	modOptions = {
		deathMode = 'builders',
		maxunits = 2000,
		map_waterlevel = 150,
		startenergy = 1500,
		startmetal = 500,
		ruins = 'enabled',
	},
	mapOptions = {
		roads = 1,
		waterlevel = 0,
		waterdamage = 0,
	},
	allyTeams = {
		thePlayerAllyTeam = {
			teams = {
				thePlayerTeam = {
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
	spawnBots = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
		},
		parameters = {
			gameFrame = 30,
			interval = 210,
		},
		actions = { 'spawnBots', 'moveBots' },
	},

	addMarkerBeginner = {
		type = triggerTypes.TimeElapsed,
		settings = {
			difficulties = { "Beginner" },
		},
		parameters = {
			gameFrame = 130,
		},
		actions = { 'addMarkerBeginner' },
	},

	addMarkerNormal = {
		type = triggerTypes.TimeElapsed,
		settings = {
			difficulties = { "Normal" },
		},
		parameters = {
			gameFrame = 130,
		},
		actions = { 'addMarkerNormal' },
	},

	addMarkerHard = {
		type = triggerTypes.TimeElapsed,
		settings = {
			difficulties = { "Hard" },
		},
		parameters = {
			gameFrame = 130,
		},
		actions = { 'addMarkerHard' },
	},
}

local actions = {
	spawnBots = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'bots',
			unitDefName = 'armpw',
			teamName = 'thePlayerTeam',
			quantity = 4,
			position = { x = 100, z = 100 },
		},
	},

	moveBots = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'bots',
			orders = {
				{ CMD.FIGHT, { 200, 0, 900 } },
				{ CMD.PATROL, { 1400, 0, 200 }, { 'shift' } },
			},
		},
	},

	addMarkerBeginner = {
		type = actionTypes.AddMarker,
		parameters = {
			position = { x = 900, z = 900 },
			label = 'Difficulty: Beginner',
		},
	},

	addMarkerNormal = {
		type = actionTypes.AddMarker,
		parameters = {
			position = { x = 900, z = 900 },
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
	LobbyData = lobbyData,
	StartScript = startScript,
	Triggers = triggers,
	Actions = actions,
}
