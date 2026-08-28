local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local initialStage = 'firstStage'
local stages = {
	firstStage = {
		objectives = { 'wait3secs' }
	},
	secondStage = {
		objectives = { 'buildBots' }
	},
	thirdStage = {
		objectives = { 'buildBots', 'destroyBots', 'noLosses' }
	}
}

local objectives = {

	wait3secs = {
		textKey = "wait_3_seconds",
		trigger = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 3,
			},
		},
	},

	buildBots = {
		textKey = "build_3_bots",
		amount = 3,
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
		trigger = {
			type = triggerTypes.UnitsOwned,
			parameters = {
				unitName = 'bots',
				teamID = 0,
			},
		},
	},

	noLosses = {
		textKey = "lose_no_units",
	},
}

local triggers = {

	advanceOnWait = {
		type = triggerTypes.ObjectiveCompleted,
		parameters = {
			objectiveID = 'wait3secs',
		},
		actions = { 'changeToSecondStage' },
	},

	spawnBots = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
			stages = { 'secondStage', 'thirdStage' },
			maxRepeats = 5,
		},
		parameters = {
			seconds = 0,
			interval = 2,
		},
		actions = { 'spawnBot' },
	},

	changeStage3 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 7,
		},
		actions = { 'changeToThirdStage', 'spawnBotDestroyer' },
	},

	failOnLoss = {
		type = triggerTypes.TotalUnitsLost,
		settings = {
			stages = { 'thirdStage' },
		},
		parameters = {
			teamID = 0,
			quantity = 1,
		},
		actions = { 'failNoLosses' },
	},

	reportFailure = {
		type = triggerTypes.ObjectiveFailed,
		parameters = {
			objectiveID = 'noLosses',
		},
		actions = { 'announceLoss' },
	},
}

local actions = {

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

	failNoLosses = {
		type = actionTypes.SetObjectiveFailed,
		parameters = {
			objectiveID = 'noLosses',
		},
	},

	announceLoss = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "A unit was lost. Objective failed.",
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
