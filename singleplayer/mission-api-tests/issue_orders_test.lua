local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local triggers = {
	spawnAttackers = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 60,
		},
		actions = { 'spawnAttackers', 'attackGround', 'messageAttackGround', 'spawnEyesA', 'spawnEyesB' },
	},

	targets1 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 200,
		},
		actions = { 'spawnTargets1a', 'spawnTargets1b', 'spawnTargets1c', 'attackNamedUnits', 'messageAttackNamedUnits' },
	},

	targets2 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 400,
		},
		actions = { 'spawnTargets2', 'areaAttack', 'messageAreaAttack' },
	},

	targets3 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 600,
		},
		actions = { 'spawnTargets3', 'fight', 'messageFight' },
	},

	spawnEnergyGrid1 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 800,
		},
		actions = { 'spawnEnergyGrid1', 'guardEnergyGrid', 'messageGuardEnergyGrid' },
	},

	reclaimEnergyGrid = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 1000,
		},
		actions = { 'reclaimEnergyGrid', 'messageReclaimEnergyGrid' },
	},

	stop = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 1200,
		},
		actions = { 'stop', 'messageStop' },
	},
}

local actions = {
	spawnAttackers = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'attackers',
            unitDefName = 'cormando',
			teamID = 0,
			position = { x = 1800, z = 1900 },
			quantity = 2,
		},
	},

	attackGround = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'attackers',
			orders = {
				{ CMD.ATTACK, { 1880, 0, 1900 } },
			},
		},
	},

	messageAttackGround  = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Some bots attacking ground.",
		},
	},

	spawnEyesA = {
		type = actionTypes.SpawnUnits,
		parameters = {
            unitDefName = 'armeyes',
			teamID = 0,
			position = { x = 1800, z = 2400 },
		},
	},

	spawnEyesB = {
		type = actionTypes.SpawnUnits,
		parameters = {
            unitDefName = 'armeyes',
			teamID = 0,
			position = { x = 2000, z = 2900 },
		},
	},

	spawnTargets1a = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'targets',
            unitDefName = 'armsolar',
			teamID = 1,
			position = { x = 1700, z = 2300 },
		},
	},

	spawnTargets1b = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'targets',
            unitDefName = 'armsolar',
			teamID = 1,
			position = { x = 1900, z = 2350 },
		},
	},

	spawnTargets1c = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'targets',
            unitDefName = 'armsolar',
			teamID = 1,
			position = { x = 2100, z = 2300 },
		},
	},

	attackNamedUnits = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'attackers',
			orders = {
				{ CMD.ATTACK, 'targets' },
			},
		},
	},

	messageAttackNamedUnits  = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Attacking targets by name, one by one.",
		},
	},

	spawnTargets2 = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'targets',
			unitDefName = 'armwin',
			teamID = 1,
			position = { x = 2000, z = 2600 },
			quantity = 2,
		},
	},

	areaAttack = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'attackers',
			orders = {
				{ CMD.MOVE_STATE, CMD.MOVESTATE_HOLDPOS },
				{ CMD.AREA_ATTACK, { 2000, 0, 2600, 300 } }, -- not working??
			},
		},
	},

	messageAreaAttack  = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Attacking area.",
		},
	},

	spawnTargets3 = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'targets',
			unitDefName = 'armsolar',
			teamID = 1,
			position = { x = 2000, z = 2800 },
			quantity = 2,
		},
	},

	fight = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'attackers',
			orders = {
				{ CMD.FIGHT, { 2000, 0, 2900 } },
			},
		},
	},

	messageFight = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Attacking using fight command.",
		},
	},

	spawnEnergyGrid1 = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'fusions',
			unitDefName = 'armfus',
			teamID = 0,
			position = { x = 2300, z = 2500 },
			quantity = 3,
		},
	},

	guardEnergyGrid = {
		-- This skips one fusion due to this bug: https://discord.com/channels/549281623154229250/1047080297042280518/threads/1371922420717588491
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'attackers',
			orders = {
				{ CMD.GUARD, 'fusions' },
			},
		},
	},

	messageGuardEnergyGrid  = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "They'll guard the fusions, one by one.",
		},
	},

	reclaimEnergyGrid = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'attackers',
			orders = {
				{ CMD.MOVE, { 2100, 0, 2100 }},
				{ CMD.RECLAIM, 'fusions', { 'shift' }  },
				{ CMD.MOVE, { 2300, 0, 2900 }, { 'shift' } },
			},
		},
	},

	messageReclaimEnergyGrid  = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Move, then reclaim the fusions, one by one, and then move again.",
		},
	},

	stop = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'attackers',
			orders = {
				{ CMD.STOP },
			},
		},
	},

	messageStop  = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Stop all that.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
