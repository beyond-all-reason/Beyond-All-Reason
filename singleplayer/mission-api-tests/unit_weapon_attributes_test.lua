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

	setRange = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 6,
		},
		actions = { 'setBotRange', 'messageSetRange' },
	},

	doubleDamage = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 12,
		},
		actions = { 'doubleTankDamage', 'messageDoubleDamage' },
	},

	boostDeathExplosion = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 18,
		},
		actions = { 'boostBotDeathExplosion', 'destroyBots', 'messageBoostDeathExplosion' },
	},

	clearDamage = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 24,
		},
		actions = { 'clearTankDamage', 'messageClearDamage' },
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
				{ unitDefName = 'armpw', x = 1800, z = 1600, team = 0, quantity = 3, unitName = 'bots' },
			},
		},
	},

	messageSpawnUnits = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'A tank and three pawns. Select a pawn to see its weapon range, and the tank to see its damage.',
		},
	},

	setBotRange = {
		type = actionTypes.SetUnitWeaponAttribute,
		parameters = {
			unitDefName = 'armpw',
			teamID = 0,
			attribute = 'maxWeaponRange',
			value = 600,
		},
	},

	messageSetRange = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'Every pawn on team 0, by def and team, now has a weapon range of 600. The tank keeps its own.',
		},
	},

	doubleTankDamage = {
		type = actionTypes.SetUnitWeaponModifier,
		parameters = {
			unitName = 'tank',
			weapon = 1,
			attribute = 'damage',
			multiplier = 2,
			source = 'overcharge',
		},
	},

	messageDoubleDamage = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'The tank, by name, now deals double damage with its first weapon, under the source overcharge.',
		},
	},

	boostBotDeathExplosion = {
		type = actionTypes.SetUnitDefWeaponModifier,
		parameters = {
			unitDefName = 'armpw',
			weapon = 'explode',
			attribute = 'damage',
			multiplier = 5,
		},
	},

	destroyBots = {
		type = actionTypes.DestroyUnits,
		parameters = {
			unitName = 'bots',
		},
	},

	messageBoostDeathExplosion = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'The pawn death explosion now deals five times its damage, and the pawns were just destroyed. Watch the tank take it.',
		},
	},

	clearTankDamage = {
		type = actionTypes.SetUnitWeaponModifier,
		parameters = {
			unitName = 'tank',
			weapon = 1,
			attribute = 'damage',
			source = 'overcharge',
		},
	},

	messageClearDamage = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'The overcharge source was cleared. The tank deals its default damage again.',
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
