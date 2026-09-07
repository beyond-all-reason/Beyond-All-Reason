local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local initialStage = 'firstStage'
local stages = {
	firstStage = {
		objectives = { 'wait3secs' }
	},
	secondStage = {
		objectives = { 'buildBots', 'patience' }
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
		nextStage = 'secondStage',
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
		onCompleted = 'botsBuilt',
	},

	-- Never completes in time, so leaving the second stage cancels it.
	patience = {
		textKey = "wait_forever",
		trigger = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 3600, -- long
			},
		},
		onCanceled = 'reportPatienceCanceled',
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

	-- Has no trigger of its own; an action fails it.
	noLosses = {
		textKey = "lose_no_units",
		onFailed = 'reportFailure',
	},

	-- Listed in no stage; an action activates it.
	killDestroyers = {
		textKey = "kill_both_destroyers",
		amount = 2,
		trigger = {
			type = triggerTypes.TotalUnitsKilled,
			parameters = {
				unitDefName = 'armllt',
				teamID = 0,
			},
		},
		onActivated = 'announceDestroyers',
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
			seconds = 0,
			interval = 2,
		},
		actions = { 'spawnBot' },
	},

	botsBuilt = {
		type = triggerTypes.Event,
		actions = { 'changeToThirdStage', 'spawnBotDestroyer', 'activateKillDestroyers' },
	},

	reportPatienceCanceled = {
		type = triggerTypes.Event,
		actions = { 'announcePatienceCanceled' },
	},

	announceDestroyers = {
		type = triggerTypes.Event,
		actions = { 'announceDestroyers' },
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
		type = triggerTypes.Event,
		actions = { 'announceLoss' },
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

	activateKillDestroyers = {
		type = actionTypes.ActivateObjective,
		parameters = {
			objectiveID = 'killDestroyers',
		},
	},

	announcePatienceCanceled = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "MissionTest: patience canceled",
		},
	},

	announceDestroyers = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "MissionTest: killDestroyers activated",
		},
	},

	failNoLosses = {
		type = actionTypes.FailObjective,
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
