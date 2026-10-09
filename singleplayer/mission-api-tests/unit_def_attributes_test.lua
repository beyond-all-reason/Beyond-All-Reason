local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {
	spawnFirstPair = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 2,
		},
		actions = { 'spawnFirstPair', 'messageSpawnFirstPair' },
	},

	setLosRadius = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 8,
		},
		actions = { 'setLosRadius', 'messageSetLosRadius' },
	},

	spawnThird = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 14,
		},
		actions = { 'spawnThird', 'messageSpawnThird' },
	},

	clearLosRadius = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 20,
		},
		actions = { 'clearLosRadius', 'messageClearLosRadius' },
	},

	halveLosRadius = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 26,
		},
		actions = { 'halveLosRadius', 'messageHalveLosRadius' },
	},

	clearHalving = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 32,
		},
		actions = { 'clearHalving', 'messageClearHalving' },
	},
}

local actions = {
	spawnFirstPair = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armpw', x = 1600, z = 2200, team = 0 },
				{ unitDefName = 'armpw', x = 1800, z = 2200, team = 0 },
			},
		},
	},

	messageSpawnFirstPair = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'Two Pawns spawned with their default sight range. Select one and note the size of its sight circle.',
		},
	},

	setLosRadius = {
		type = actionTypes.SetUnitDefAttribute,
		parameters = {
			unitDefName = 'armpw',
			attribute = 'losRadius',
			value = 1200,
		},
	},

	messageSetLosRadius = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'losRadius of the Pawn def set to 1200. Both existing Pawns should now show a much larger sight circle.',
		},
	},

	spawnThird = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armpw', x = 2000, z = 2200, team = 0 },
			},
		},
	},

	messageSpawnThird = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'A third Pawn spawned after the change. Its sight circle should match the other two.',
		},
	},

	clearLosRadius = {
		type = actionTypes.ClearUnitDefAttribute,
		parameters = {
			unitDefName = 'armpw',
			attribute = 'losRadius',
		},
	},

	messageClearLosRadius = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'The losRadius set was cleared. All three Pawns should be back to their default sight circle.',
		},
	},

	halveLosRadius = {
		type = actionTypes.SetUnitDefModifier,
		parameters = {
			unitDefName = 'armpw',
			attribute = 'losRadius',
			multiplier = 0.5,
			source = 'fog',
		},
	},

	messageHalveLosRadius = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'A modifier named fog halved the Pawn def losRadius. All three sight circles should shrink to half.',
		},
	},

	clearHalving = {
		type = actionTypes.ClearUnitDefModifier,
		parameters = {
			unitDefName = 'armpw',
			attribute = 'losRadius',
			source = 'fog',
		},
	},

	messageClearHalving = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'The fog modifier was cleared. The sight circles should be back to their default size.',
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
