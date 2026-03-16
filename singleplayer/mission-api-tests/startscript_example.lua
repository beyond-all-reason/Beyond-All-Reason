local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local triggers = {}
local actions = {}

--[[
All these modOptions need to be added to the start script by the lobby:

	missionScriptPath = "" -- path to the mission script to load, relative to VFS root.
	difficulty = "Hard" -- player's choice, needed for difficulty-based triggers and actions to work
maps of custom names to IDs of ally teams, teams, and AIs, needed for triggers and actions to refer to them by name:
	allyTeams = { someCustomAllyTeamName = 0, anotherCustomAllyTeamName = 1 }
	teams = { someCustomTeamName = 0, anotherCustomTeamName = 1 }
	ais = { someCustomTeamName = 0 }
]]

local lobbyData = { -- display in lobby, inspired by https://www.figma.com/design/XmKdpNvdclGEVwW6c2EaKH/BAR_new-client?node-id=228-2&p=f&t=m6SWIi6tC92CRpZi-0
	title = "The Stars are Falling",
	description = "Lorem Ipsum ...",
	alliesPresent = { "Fortified Outpost", "Reinforcements en route" },
	objectives = { "Build a base.", "Obliterate their nukes." },
	knownHostiles = { "Raptors - extremely likely", "Unidentified raiders - inbound" },
	newUnits = {
		armflash = "Blitz - a fast assault tank.",
		armcv = "Construction Vehicle - builds structures.",
	},
	startPos = { x = 40, y = 0 }, -- marker on map in lobby to indicate the player's starting position
	imageFiles = { "startscript_example.jpg" }, -- placed next to lua file (or relative to VFS root?)
}

local startScript = {

	mapName = "Fallendell V4", -- as displayed in the map selection screen, must be exact. Lobby to replace spaces with underscores
	startPosType = 'chooseBeforeGame', -- lobby to map this: fixed = 0, random = 1, chooseInGame = 2, chooseBeforeGame = 3
	players = { min = 1, max = 4 },
	unitLimits = {
		armavp = 0, -- example of a unit limit, set to 0 to disable the unit
		coravp = 5,
	},
	difficulties = {
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
			startRectTop = 0.12, -- these are only needed when startPosType is 'chooseInGame'
			startRectLeft = 1,
			startRectBottom = 0,
			startRectRight = 0,
			teams = {
				someCustomTeamName = {
					name = "Armada Stronghold Guard", -- in-game name, lobby can display it or ignore
					Side = 'Cortex',
					StartPosX = 5000, -- only needed when startPosType is 'chooseBeforeGame'
					StartPosZ = 1400,
					IncomeMultiplier = 1,
					ai = "SimpleAI", -- lobby to pass this as shortName
				},
			},
		},
		anotherCustomAllyTeamName = {
			teams = {
				anotherCustomTeamName = {
					Side = 'Armada',
					StartPosX = 5000, -- only needed when startPosType is 'chooseBeforeGame'
					StartPosZ = 1400,
					ai = nil, -- is a player
				},
			}
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
	LobbyData = lobbyData,
	StartScript = startScript,
}
