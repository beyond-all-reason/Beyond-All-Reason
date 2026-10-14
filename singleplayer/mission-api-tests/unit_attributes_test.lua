local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {
	spawnUnits = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 2,
		},
		actions = { 'spawnTank', 'spawnBots', 'messageSpawnUnits' },
	},

	setSpeed = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 6,
		},
		actions = { 'setTankSpeed', 'moveTank', 'messageSetSpeed' },
	},

	setStealth = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 12,
		},
		actions = { 'setTankStealth', 'messageSetStealth' },
	},

	clearStealth = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 16,
		},
		actions = { 'clearTankStealth', 'messageClearStealth' },
	},
}

local actions = {
	spawnTank = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armstump', x = 2300, z = 1900, team = 0, unitName = 'tank' },
			},
		},
	},

	spawnBots = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armpw', x = 1800, z = 1600, team = 0, quantity = 3 },
			},
		},
	},

	messageSpawnUnits = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'A tank and three pawns. Select the tank to note its speed.',
		},
	},

	setTankSpeed = {
		type = actionTypes.SetUnitAttribute,
		parameters = {
			unitName = 'tank',
			attribute = 'speed',
			value = 240,
		},
	},

	moveTank = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'tank',
			orders = {
				{ CMD.MOVE, { 3000, 0, 2600 } },
			},
		},
	},

	messageSetSpeed = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'The tank, by name, now has a speed of 240. The move order just given makes it take effect.',
		},
	},

	setTankStealth = {
		type = actionTypes.SetUnitAttribute,
		parameters = {
			unitName = 'tank',
			attribute = 'stealth',
			value = true,
		},
	},

	messageSetStealth = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'The tank, by name, is now stealthy: enemy radar no longer shows it.',
		},
	},

	clearTankStealth = {
		type = actionTypes.ClearUnitAttribute,
		parameters = {
			unitName = 'tank',
			attribute = 'stealth',
		},
	},

	messageClearStealth = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'The stealth set was cleared. Enemy radar shows the tank again.',
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
