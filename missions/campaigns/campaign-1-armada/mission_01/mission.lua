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
	mapName = "Fallendell V4", -- as displayed in the map selection screen, must be exact. Lobby to replace spaces with underscores
	startPosType = 'chooseBeforeGame', -- lobby to map this: fixed = 0, random = 1, chooseInGame = 2, chooseBeforeGame = 3
	players = { min = 1, max = 4 },
	unitLimits = {
		armavp = 0, -- example of a unit limit, set to 0 to disable the unit
		coravp = 5,
	},
	difficulties = { -- should probably be part of the campaign or even global game data, not per mission
		{ name = "Beginner", playerhandicap = 50, enemyhandicap = 0 }, -- handicap values range [-100 - +100], with 0 being regular resources
		{ name = "Normal", playerhandicap = 0, enemyhandicap = 0 }, -- but do we want resource handicaps as part of difficulty??
		{ name = "Hard", playerhandicap = 0, enemyhandicap = 25 },
	},
	defaultDifficulty = "Normal", -- an entry of the difficulty table
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
		someCustomAllyTeamName = {
			teams = {
				someCustomTeamName = {
					name = "PlayerPawns", -- in-game name, player name rules apply, so no spaces etc...
					Side = 'Cortex',
					StartPosX = 700, -- used when startPosType is 'fixed'
					StartPosZ = 700,
					ai = nil, -- is a player
				},
			},
		},
		anotherCustomAllyTeamName = {
			teams = {
				anotherCustomTeamName = {
					name = "Mission Bots",
					Side = 'Armada',
					StartPosX = 3000, -- used when startPosType is 'fixed'
					StartPosZ = 2400,
					IncomeMultiplier = 1.5,
					ai = "SimpleAI", -- lobby to pass this as shortName
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
}

local actions = {
	spawnBots = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'bots',
			unitDefName = 'armpw',
			teamID = 0,
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
}

return {
	LobbyData = lobbyData,
	StartScript = startScript,
	Triggers = triggers,
	Actions = actions,
}
