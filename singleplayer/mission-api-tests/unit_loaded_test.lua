local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

-- A transport loads and unloads a named pawn. A construction vehicle with an attached turret is
-- spawned alongside: the attachment raises the same engine call-in and must not fire the
-- passenger triggers. Docking drones behave the same way, but no carrier is a base-game land unit.

local triggers = {

	spawnScene = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 1,
		},
		actions = { 'spawnDropship', 'spawnPassenger', 'spawnConstructor' },
	},

	-- Split off the spawn, since an order does not take on the frame its target unit is spawned.
	orderTransport = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 3,
		},
		actions = { 'orderDropshipLoadAndUnload' },
	},

	passengerLoaded = {
		type = triggerTypes.UnitLoaded,
		parameters = {
			unitName = 'passenger',
		},
		actions = { 'messagePassengerLoaded' },
	},

	pawnLoadedByAtlas = {
		type = triggerTypes.UnitLoaded,
		parameters = {
			unitDefName = 'armpw',
			teamID = 0,
			transportDefName = 'armatlas',
		},
		actions = { 'messagePawnLoadedByAtlas' },
	},

	passengerUnloaded = {
		type = triggerTypes.UnitUnloaded,
		parameters = {
			unitName = 'passenger',
			transportName = 'dropship',
		},
		actions = { 'messagePassengerUnloaded' },
	},

	-- Never fires: the construction vehicle is not a transport.
	turretAttached = {
		type = triggerTypes.UnitLoaded,
		parameters = {
			unitDefName = 'corvacct',
		},
		actions = { 'messageTurretAttached' },
	},

}

local actions = {

	spawnDropship = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armatlas', x = 2400, z = 2400, team = 0, unitName = 'dropship' },
			},
		},
	},

	spawnPassenger = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armpw', x = 2480, z = 2400, team = 0, unitName = 'passenger' },
			},
		},
	},

	spawnConstructor = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'corvac', x = 2200, z = 2400, team = 0 },
			},
		},
	},

	orderDropshipLoadAndUnload = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'dropship',
			orders = {
				{ CMD.LOAD_UNITS, { unitName = 'passenger' } },
				{ CMD.UNLOAD_UNITS, { 2400, 0, 2700, 60 }, { 'shift' } },
			},
		},
	},

	messagePassengerLoaded = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "The passenger boarded a transport!",
		},
	},

	messagePawnLoadedByAtlas = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "A pawn boarded an Atlas!",
		},
	},

	messagePassengerUnloaded = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "The dropship unloaded the passenger!",
		},
	},

	messageTurretAttached = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "BUG: an attached turret counted as loaded into a transport!",
		},
	},

}

return {
	Triggers = triggers,
	Actions = actions,
}
