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
--[[
	despawnHero = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
		},
		parameters = {
			gameFrame = 90,
			interval = 180,
		},
		actions = { 'despawnHero' },
	},]]--

	gameEnd = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = false,
		},
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
			unitDefName = 'coraca',
			position = { x = 100, z = 200 },
			quantity = 2,
			facing = 'n',
		},
	},
--[[
	despawnHero = {
		type = actionTypes.DespawnUnits,
		parameters = {
			name = 'hero',
		},
	},--]]

	gameEnd = {
		type = actionTypes.Defeat,
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
