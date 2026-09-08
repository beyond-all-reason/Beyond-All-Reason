local triggerTypes = GG["MissionAPI"].TriggerDefinitions.Types
local actionTypes = GG["MissionAPI"].ActionDefinitions.Types

local triggers = {

	spawnActors = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 1,
		},
		actions = { "spawnActors", "messageIntro" },
	},

	-- Orders issued by the mission itself are not visible, by default.
	botsOrdered = {
		type = triggerTypes.UnitOrdered,
		settings = {
			repeating = true,
			maxRepeats = 77,
		},
		parameters = {
			command = CMD.ANY,
			unitName = "bots",
		},
		actions = { "messageBotsOrdered" },
	},

	-- Sometimes, though, we don't care who gave the order. See ignoreMissionActions below.
	botsMoved = {
		type = triggerTypes.UnitOrdered,
		settings = {
			repeating = true,
			maxRepeats = 77,
		},
		parameters = {
			command = CMD.MOVE,
			unitName = "bots",
			ignoreMissionActions = false,
		},
		actions = { "messageBotsMoved" },
	},

	missionMovesBots = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 8,
		},
		actions = { "moveBots", "messageMissionMovesBots" },
	},

	conBuildOrdered = {
		type = triggerTypes.UnitOrdered,
		settings = {
			repeating = true,
			maxRepeats = 77,
		},
		parameters = {
			command = CMD.BUILD,
			unitName = "cons",
			ignoreMissionActions = false,
		},
		actions = { "messageConBuildOrdered" },
	},

	conSolarOrdered = {
		type = triggerTypes.UnitOrdered,
		settings = {
			repeating = true,
			maxRepeats = 77,
		},
		parameters = {
			command = "armsolar",
			unitName = "cons",
			ignoreMissionActions = false,
		},
		actions = { "messageConSolarOrdered" },
	},

	missionOrdersSolar = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 15,
		},
		actions = { "orderSolar", "messageMissionOrdersSolar" },
	},

	labRallied = {
		type = triggerTypes.RallyOrdered,
		settings = {
			repeating = true,
			maxRepeats = 77,
		},
		parameters = {
			command = CMD.MOVE,
			unitName = "lab",
			ignoreMissionActions = false,
		},
		actions = { "messageLabRallied" },
	},

	labExecuted = {
		type = triggerTypes.UnitOrdered,
		settings = {
			repeating = true,
			maxRepeats = 77,
		},
		parameters = {
			command = CMD.ANY,
			unitName = "lab",
			ignoreMissionActions = false,
		},
		actions = { "messageLabExecuted" },
	},

	missionRalliesLab = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 22,
		},
		actions = { "rallyLab", "messageMissionRalliesLab" },
	},

	missionTogglesLab = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 29,
		},
		actions = { "toggleLab", "messageMissionTogglesLab" },
	},

	missionQueuesPawn = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 36,
		},
		actions = { "queuePawn", "messageMissionQueuesPawn" },
	},
}

local actions = {

	spawnActors = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{
					unitDefName = "armpw",
					x = 1800,
					z = 1600,
					teamName = "thePlayerTeam",
					unitName = "bots",
					quantity = 2,
				},
				{ unitDefName = "armck", x = 1700, z = 2000, teamName = "thePlayerTeam", unitName = "cons" },
				{
					unitDefName = "armlab",
					x = 2100,
					z = 2000,
					facing = "s",
					teamName = "thePlayerTeam",
					unitName = "lab",
				},
			},
		},
	},

	messageIntro = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Order the bots yourself: each order you give shows a message.",
		},
	},

	messageBotsOrdered = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Bots received your order!",
		},
	},

	messageBotsMoved = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Bots received a move order!",
		},
	},

	moveBots = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = "bots",
			orders = {
				{ CMD.MOVE, { 1800, 0, 2400 } },
			},
		},
	},

	messageMissionMovesBots = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Mission moves the bots. The move message shows; the your-order message stays quiet.",
		},
	},

	messageConBuildOrdered = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Constructor received a build order!",
		},
	},

	messageConSolarOrdered = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "A solar, specifically!",
		},
	},

	orderSolar = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = "cons",
			orders = {
				{ "armsolar", { 1600, 0, 2100, 1 } },
			},
		},
	},

	messageMissionOrdersSolar = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Mission orders a solar built. Both build messages show.",
		},
	},

	messageLabRallied = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Factory received a rally order!",
		},
	},

	messageLabExecuted = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Factory executed a direct command!",
		},
	},

	rallyLab = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = "lab",
			orders = {
				{ CMD.MOVE, { 2200, 0, 2400 } },
			},
		},
	},

	messageMissionRalliesLab = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Mission rallies the lab. Rally message only; try setting a rally yourself, too.",
		},
	},

	toggleLab = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = "lab",
			orders = {
				{ CMD.MOVE_STATE, 1 },
			},
		},
	},

	messageMissionTogglesLab = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Mission sets the lab's move state. Direct-command message only; no rally message.",
		},
	},

	queuePawn = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = "lab",
			orders = {
				{ "armpw", {} },
			},
		},
	},

	messageMissionQueuesPawn = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Mission queues a Pawn at the lab. Nothing fires: factory production needs ProductionOrdered.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
