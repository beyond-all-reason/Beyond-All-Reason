local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local objectives = {
	wait = {
		text = "Wait a bit.",
	},
	buildBots = {
		text = "Build some grunts.",
		amount = 3,
	},
	destroyBots = {
		text = "Destroy the grunts.",
		amount = 0,
	},
}

local initialStage = 'firstStage'
local stages = {

	firstStage = {
		title = "The First Stage",
		objectives = { 'wait' },
	},

	secondStage = {
		title = "The Second Stage",
		objectives = { 'buildBots' },
	},

	thirdStage = {
		title = "The Third Stage",
		objectives = { 'buildBots', 'destroyBots' },
	},
}

local triggers = {

	messageFirstStage = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
			stages = { 'firstStage' },
		},
		parameters = {
			gameFrame = 1,
			interval = 60,
		},
		actions = { 'messageFirstStage' },
	},

	messageSecondStage = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
			maxRepeats = 0,
			stages = { 'secondStage' },
		},
		parameters = {
			gameFrame = 1,
			interval = 60,
		},
		actions = { 'messageSecondStage' },
	},

	waitDone = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = false,
		},
		parameters = {
			gameFrame = 90,
		},
		actions = { 'waitDone' },
	},

	changeStage2 = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = false,
		},
		parameters = {
			gameFrame = 150,
		},
		actions = { 'changeToSecondStage' },
	},

	spawnBots = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
			maxRepeats = 2,
			stages = { 'secondStage' },
		},
		parameters = {
			gameFrame = 1,
			interval = 30,
		},
		actions = { 'spawnBot', 'updateBuildBotsObjective' },
	},

	changeStage3 = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = false,
		},
		parameters = {
			gameFrame = 240,
		},
		actions = { 'changeToThirdStage', 'spawnBotDestroyer' },
	},

	destroyBots = {
		type = triggerTypes.TimeElapsed, -- since UnitDestroyed is not implemented yet
		settings = {
			repeating = true,
			stages = { 'thirdStage' },
		},
		parameters = {
			gameFrame = 1,
			interval = 15,
		},
		actions = { 'updateDestroyBotsObjective' },
	},
}

local actions = {

	messageFirstStage = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "This is the FIRST stage",
		},
	},

	messageSecondStage = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "This is the SECOND stage",
		},
	},

	waitDone = {
		type = actionTypes.UpdateObjective,
		parameters = {
			objectiveID = 'wait',
			completed = true,
			text = "Wait a bit - TEXT UPDATED!",
		},
	},

	changeToSecondStage = {
		type = actionTypes.ChangeStage,
		parameters = {
			stageID = 'secondStage',
		},
	},

	spawnBot = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'corak', x = 1800, z = 1800, team = 0, unitName = 'bots' },
			},
		},
	},

	updateBuildBotsObjective = {
		type = actionTypes.UpdateObjective,
		parameters = {
			objectiveID = 'buildBots',
			unitName = 'bots',
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
				{ unitDefName = 'armllt', x = 1800, z = 2200, team = 1 },
			},
		},
	},

	updateDestroyBotsObjective = {
		type = actionTypes.UpdateObjective,
		parameters = {
			objectiveID = 'destroyBots',
			unitName = 'bots',
		},
	},
}

return {
	InitialStage = initialStage,
	Stages = stages,
	Objectives = objectives,
	Triggers = triggers,
	Actions = actions,
}
