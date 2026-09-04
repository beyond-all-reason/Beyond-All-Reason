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

	-- Completing buildBots is the only way into the third stage.
	botsBuilt = {
		type = triggerTypes.ObjectiveCompleted,
		parameters = {
			objectiveID = 'buildBots',
		},
		actions = { 'changeToThirdStage', 'spawnBotDestroyer', 'activateKillDestroyers' },
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

	-- Once the bots are gone, the destroyers no longer matter.
	botsDestroyed = {
		type = triggerTypes.ObjectiveCompleted,
		parameters = {
			objectiveID = 'destroyBots',
		},
		actions = { 'deactivateKillDestroyers' },
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

	failNoLosses = {
		type = actionTypes.Custom,
		parameters = {
			['function'] = function()
				GG['MissionAPI'].Modules.Objectives.FailObjective('noLosses')
			end,
		},
	},

	announceLoss = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "A unit was lost. Objective failed.",
		},
	},

	activateKillDestroyers = {
		type = actionTypes.ActivateObjective,
		parameters = {
			objectiveID = 'killDestroyers',
		},
	},

	deactivateKillDestroyers = {
		type = actionTypes.DeactivateObjective,
		parameters = {
			objectiveID = 'killDestroyers',
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
