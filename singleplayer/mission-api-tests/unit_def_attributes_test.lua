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
		type = actionTypes.SetUnitDefAttribute,
		parameters = {
			unitDefName = 'armpw',
			attribute = 'losRadius',
		},
	},

	messageClearLosRadius = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'The losRadius set was cleared, with no value. All three Pawns should be back to their default sight circle.',
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
