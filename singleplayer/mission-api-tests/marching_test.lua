local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

-- One squad of fast and slow bots marching on a timer. Each march shows one parameter.
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

	queueTwoMoves = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 83,
		},
		actions = { 'moveNorth', 'queueMoveEastFacingNorth', 'messageQueue' },
	},

	matchSpeed = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 150,
		},
		actions = { 'moveWestMatchingSpeed', 'messageMatchSpeed' },
	},
}

local actions = {

	spawnSquad = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armpw', position = { x = 1750, z = 2600 }, teamName = 'player', unitName = 'squad', quantity = 4 },
				{ unitDefName = 'armham', position = { x = 1750, z = 2750 }, teamName = 'player', unitName = 'squad', quantity = 2 },
				{ unitDefName = 'armwar', position = { x = 1750, z = 2900 }, teamName = 'player', unitName = 'squad' },
			},
		},
	},

	moveEastKeepingShape = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'squad',
			orders = { { CMD.MOVE, { 3250, 0, 2750 } } },
			marching = true,
		},
	},

	messageKeepShape = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Marching east: the squad keeps its shape.",
		},
	},

	moveSouthFacingSouth = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'squad',
			orders = { { CMD.MOVE, { 3250, 0, 4250 } } },
			marching = true,
			direction = { angle = 180 },
		},
	},

	messageTurnShape = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Marching south with direction 180: the squad turns to face south.",
		},
	},

	moveNorth = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'squad',
			orders = { { CMD.MOVE, { 2000, 0, 3000 } } },
			marching = true,
		},
	},

	queueMoveEastFacingNorth = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'squad',
			orders = { { CMD.MOVE, { 3250, 0, 3000 }, { 'shift' } } },
			marching = true,
			direction = { x = 3250, z = 0 },
		},
	},

	messageQueue = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Two moves, the second queued and facing a point to the north.",
		},
	},

	moveWestMatchingSpeed = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'squad',
			orders = { { CMD.MOVE, { 2000, 0, 3000 } } },
			marching = true,
			matchSpeed = true,
		},
	},

	messageMatchSpeed = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Marching west with matchSpeed: the fast bots hold the slow one's pace.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
