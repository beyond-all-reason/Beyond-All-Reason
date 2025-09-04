local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local triggers = {
	testTime = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = false,
		},
		parameters = {
			gameFrame = 150,
			interval = 60,
		},
		actions = { 'helloWorld' },
	},

	spawnHero = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = false,
		},
		parameters = {
			gameFrame = 1,
			interval = 180,
		},
		actions = { 'spawnHero' },
	},

	despawnHero = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = false,
		},
		parameters = {
			gameFrame = 160,
			interval = 180,
		},
		actions = { 'despawnHero' },
	},

	gameEnd = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 210,
		},
		actions = { 'gameEnd' },
	},
}

local actions = {
	helloWorld = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Hello World",
		},
	},

	spawnHero = {
		type = actionTypes.SpawnUnits,
		parameters = {
			name = 'hero',
            unitDefName = 'corck',
			teamID = 0,
			positions = {{ x = 1800, z = 1600 }, { x = 1900, z = 1600 }},
			facing = 'n',
		},
	},

	despawnHero = {
		type = actionTypes.DespawnUnits,
		parameters = {
			name = 'hero',
            selfDescruct = false,
			reclaimed = false
		},
	},

	gameEnd = {
		type = actionTypes.Defeat,
		parameters = {
			allyTeamIDs = {0},
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
