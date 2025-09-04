local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local triggers = {

	spawnConBots = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
		},
		parameters = {
			gameFrame = 1,
			interval = 280,
		},
		actions = { 'spawnConBots', 'moveConBots' },
	},

	despawnConBotsAsKilled = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = false,
		},
		parameters = {
			gameFrame = 200,
		},
		actions = { 'despawnConBotsAsKilled', 'messageBotsKilled' },
	},

	despawnConBotsSelfD = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = false,
		},
		parameters = {
			gameFrame = 480,
		},
		actions = { 'despawnConBotsSelfD', 'messageBotsSelfD' },
	},

	despawnConBotsReclaimed = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = false,
		},
		parameters = {
			gameFrame = 760,
		},
		actions = { 'despawnConBotsReclaimed', 'messageBotsReclaimed' },
	},

	gameEnd = {
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
			positions = {{ x = 1800, z = 1600 }, { x = 1900, z = 1600 }},
			facing = 'n',
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
            selfDescruct = false,
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
            selfDescruct = true,
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
            selfDescruct = false,
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
