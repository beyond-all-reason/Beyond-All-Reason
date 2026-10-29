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
				{ unitDefName = 'armpw', x = 1000, z = 1000, team = 0, unitName = 'squad', quantity = 4 },
				{ unitDefName = 'armham', x = 1000, z = 1150, team = 0, unitName = 'squad', quantity = 2 },
				{ unitDefName = 'armwar', x = 1000, z = 1300, team = 0, unitName = 'squad' },
			},
		},
	},

	moveEastKeepingShape = {
		type = actionTypes.IssueFormationOrders,
		parameters = {
			unitName = 'squad',
			position = { x = 2400, z = 1150 },
		},
	},

	messageKeepShape = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Moving east: the squad keeps its shape.",
		},
	},

	moveSouthFacingSouth = {
		type = actionTypes.IssueFormationOrders,
		parameters = {
			unitName = 'squad',
			position = { x = 2400, z = 2400 },
			direction = { angle = 180 },
		},
	},

	messageTurnShape = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Moving south with direction 180: the shape turns to face south.",
		},
	},

	fightAlongLine = {
		type = actionTypes.IssueFormationOrders,
		parameters = {
			unitName = 'squad',
			command = CMD.FIGHT,
			positions = { { x = 1400, z = 3000 }, { x = 2000, z = 3200 }, { x = 2600, z = 3000 } },
		},
	},

	messageLineUp = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Fight along a bent line: spread evenly, each bot matched to a spot.",
		},
	},

	moveNorth = {
		type = actionTypes.IssueFormationOrders,
		parameters = {
			unitName = 'squad',
			position = { x = 1000, z = 1800 },
		},
	},

	queueMoveEastFacingNorth = {
		type = actionTypes.IssueFormationOrders,
		parameters = {
			unitName = 'squad',
			position = { x = 2400, z = 1800 },
			direction = { x = 2400, z = 0 },
			queue = true,
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
