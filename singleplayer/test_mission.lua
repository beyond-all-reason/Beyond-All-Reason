local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local triggers = {

	spawnConBots = {
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

	spawnThors = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 150,
		},
		actions = { 'spawnThors' },
	},

	at200 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 200,
		},
		actions = { 'despawnConBotsAsKilled', 'messageBotsKilled' },
	},

	at480 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 480,
		},
		actions = { 'despawnConBotsSelfD', 'messageBotsSelfD' },
	},

	at760 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 760,
		},
		actions = { 'despawnConBotsReclaimed', 'messageBotsReclaimed' },
	},

	at900 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 900,
		},
		actions = { 'gameEnd' },
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
			alert = true,
		},
	},

	spawnThors = {
		type = actionTypes.SpawnUnits,
		parameters = {
            unitDefName = 'armthor',
			teamID = 0,
			position = { x = 1800, z = 2100 },
			quantity = 11,
			spacing = 100,
			facing = 'n',
			alert = true,
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
