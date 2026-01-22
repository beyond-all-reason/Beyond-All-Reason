local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local triggers = {

	at1each200spawnConBotsAndMove = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
			maxRepeats = 3,
		},
		parameters = {
			gameFrame = 1,
			interval = 280,
		},
		actions = { 'spawnConBots', 'moveConBots' },
	},

	at150spawnFusions = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 150,
		},
		actions = { 'spawnFusions' },
	},

	at200killConBots = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 200,
		},
		actions = { 'despawnConBotsAsKilled', 'messageBotsKilled' },
	},

	at480selfDestructConBots = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 480,
		},
		actions = { 'despawnConBotsSelfD', 'messageBotsSelfD' },
	},

	at760reclaimConBots = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 760,
		},
		actions = { 'despawnConBotsReclaimed', 'messageBotsReclaimed' },
	},

	at900giveConBotsToAI = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 900,
		},
		actions = { 'transferConBotsToAI', 'messageBotsToAI' },
	},

	at1100giveConBotsToPlayer = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 1100,
		},
		actions = { 'transferConBotsToPlayer', 'messageBotsToPlayer' },
	},

	at1300gameEnd = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 1300,
		},
		actions = { 'gameEnd' },
	},

	----------------------------------------------------------------
	--- Triggers only testing validation:
	----------------------------------------------------------------

	triggerWithNoActions = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = math.maxinteger,
		},
	},

	triggerWithInvalidActionID = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = math.maxinteger,
		},
		actions = { 'invalidActionID' },
	},
}

local actions = {

	spawnConBots = {
		type = actionTypes.SpawnUnits,
		parameters = {
			name = 'con-bots',
            unitDefName = 'corck',
			teamID = 0,
			position = { x = 1800, z = 1600 },
			quantity = 9,
			facing = 'n',
		},
	},

	spawnFusions = {
		type = actionTypes.SpawnUnits,
		parameters = {
            unitDefName = 'armfus',
			teamID = 0,
			position = { x = 1900, z = 2200 },
			quantity = 18,
			facing = 'e',
		},
	},

	moveConBots = {
		type = actionTypes.IssueOrders,
		parameters = {
			name = 'con-bots',
			orders = {
				{ CMD.MOVE, { 1850, 0, 1500 }, CMD.OPT_SHIFT },
				{ CMD.MOVE, { 1850, 0, 1800 }, CMD.OPT_SHIFT },
			},
		},
	},

	despawnConBotsAsKilled = {
		type = actionTypes.DespawnUnits,
		parameters = {
			name = 'con-bots',
			selfDestruct = false,
			reclaimed = false
		},
	},

	messageBotsKilled = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Let's kill those bots.",
		},
	},

	despawnConBotsSelfD = {
		type = actionTypes.DespawnUnits,
		parameters = {
			name = 'con-bots',
			selfDestruct = true,
			reclaimed = false
		},
	},

	messageBotsSelfD = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "They blow themselves up!",
		},
	},

	despawnConBotsReclaimed = {
		type = actionTypes.DespawnUnits,
		parameters = {
			name = 'con-bots',
			selfDestruct = false,
			reclaimed = true
		},
	},

	messageBotsReclaimed = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "These just vanish...",
		},
	},

	transferConBotsToAI = {
		type = actionTypes.TransferUnits,
		parameters = {
			name = 'con-bots',
			newTeam = 1,
			given = false
		},
	},

	messageBotsToAI = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "We give these away.",
		},
	},

	transferConBotsToPlayer = {
		type = actionTypes.TransferUnits,
		parameters = {
			name = 'con-bots',
			newTeam = 0,
			given = false
		},
	},

	messageBotsToPlayer = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "And we take them back.",
		},
	},

	gameEnd = {
		type = actionTypes.Defeat,
		parameters = {
			allyTeamIDs = { 0 },
		},
	},

	----------------------------------------------------------------
	--- Unreferenced actions testing validation:
	----------------------------------------------------------------

	actionWithInvalidTriggerID = {
		type = actionTypes.EnableTrigger,
		parameters = {
			triggerID = 'invalidTriggerID',
		},
	},

	actionWithInvalidTeamIDAndInvalidUnitDefName = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitDefName = 'invalidUnitDefName',
			teamID = 6,
			position = { x = 1800, z = 1600 },
			facing = 'invalidFacing',
		},
	},

	actionWithInvalidAllyTeamID = {
		type = actionTypes.Defeat,
		parameters = {
			allyTeamIDs = { 777 },
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
