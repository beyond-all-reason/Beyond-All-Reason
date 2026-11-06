local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

-- One squad of fast and slow bots, moved on a timer. Each move shows one parameter.
local triggers = {

	start = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 1,
		},
		actions = { 'spawnSquad' },
	},

	keepShape = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 3,
		},
		actions = { 'moveEastKeepingShape', 'messageKeepShape' },
	},

	turnShape = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 43,
		},
		actions = { 'moveSouthFacingSouth', 'messageTurnShape' },
	},

	lineUp = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 83,
		},
		actions = { 'fightAlongLine', 'messageLineUp' },
	},

	queueTwoMoves = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 113,
		},
		actions = { 'moveNorth', 'queueMoveEastFacingNorth', 'messageQueue' },
	},
}

local actions = {

	spawnSquad = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armpw', x = 1000, z = 1000, teamName = 'player', unitName = 'squad', quantity = 4 },
				{ unitDefName = 'armham', x = 1000, z = 1150, teamName = 'player', unitName = 'squad', quantity = 2 },
				{ unitDefName = 'armwar', x = 1000, z = 1300, teamName = 'player', unitName = 'squad' },
			},
		},
	},

	moveEastKeepingShape = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'squad',
			orders = { { CMD.MOVE, { 2400, 0, 1150 } } },
			formation = {},
		},
	},

	messageKeepShape = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Moving east: the squad keeps its shape.",
		},
	},

	moveSouthFacingSouth = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'squad',
			orders = { { CMD.MOVE, { 2400, 0, 2400 } } },
			formation = { direction = { angle = 180 } },
		},
	},

	messageTurnShape = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Moving south with direction 180: the shape turns to face south.",
		},
	},

	fightAlongLine = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'squad',
			-- Several points in one order are a line.
			orders = { { CMD.FIGHT, { 1400, 0, 3000, 2000, 0, 3200, 2600, 0, 3000 } } },
			formation = {},
		},
	},

	messageLineUp = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Fight along a bent line: spread evenly, each bot matched to a spot.",
		},
	},

	moveNorth = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'squad',
			orders = { { CMD.MOVE, { 1000, 0, 1800 } } },
			formation = {},
		},
	},

	queueMoveEastFacingNorth = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'squad',
			orders = { { CMD.MOVE, { 2400, 0, 1800 }, { 'shift' } } },
			formation = { direction = { x = 2400, z = 0 } },
		},
	},

	messageQueue = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Two moves, the second queued and facing a point to the north.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
