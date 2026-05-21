local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local initialStage = 'firstStage'
local objectives = {

	wait3secs = {
		textKey = "wait_3_seconds",
		stages = { 'firstStage' },
		trigger = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				gameFrame = 90,
			},
		},
		nextStage = 'secondStage',
	},

	buildBots = {
		textKey = "build_3_bots",
		amount = 3,
		stages = { 'secondStage', 'thirdStage' },
		trigger = {
			type = triggerTypes.ConstructionFinished,
			parameters = {
				unitDefName = 'corak',
				teamID = 0,
			},
		},
	},

	destroyBots = {
		textKey = "destroy_all_bots",
		amount = 0,
		stages = { 'thirdStage' },
		trigger = {
			type = triggerTypes.UnitsOwned,
			parameters = {
				unitName = 'bots',
				teamID = 0,
			},
		},
	},
}

local triggers = {

	spawnBots = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
			stages = { 'secondStage', 'thirdStage' },
			maxRepeats = 5,
		},
		parameters = {
			gameFrame = 5,
			interval = 60,
		},
		actions = { 'spawnBot' },
	},

	changeStage3 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 210,
		},
		actions = { 'changeToThirdStage', 'spawnBotDestroyer' },
	},
}

local actions = {

	spawnBot = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'corak', x = 1800, z = 1800, team = 0, unitName = 'bots' },
			},
		},
	},

	changeToThirdStage = {
		type = actionTypes.ChangeStage,
		parameters = {
			stageID = 'thirdStage',
		},
	},

	spawnBotDestroyer = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armllt', x = 1800, z = 2200, team = 1, quantity = 2 },
			},
		},
	},
}

return {
	InitialStage = initialStage,
	Objectives = objectives,
	Triggers = triggers,
	Actions = actions,
}
