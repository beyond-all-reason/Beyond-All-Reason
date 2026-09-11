local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

-- A transport loads and unloads a pawn. A construction vehicle with an attached turret is spawned
-- alongside: the attachment raises the same engine call-in, and counts as a transport event only
-- when the mission names the vehicle's definition. Docking drones behave the same way, but no
-- carrier is a base-game land unit.

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

	dropshipLoaded = {
		type = triggerTypes.TransportLoaded,
		parameters = {
			transportName = 'dropship',
		},
		actions = { 'messageDropshipLoaded' },
	},

	atlasLoadedPawn = {
		type = triggerTypes.TransportLoaded,
		parameters = {
			transportDefName = 'armatlas',
			teamID = 0,
			passengerDefName = 'armpw',
		},
		actions = { 'messageAtlasLoadedPawn' },
	},

	dropshipUnloaded = {
		type = triggerTypes.TransportUnloaded,
		parameters = {
			transportName = 'dropship',
			unitName = 'passenger',
		},
		actions = { 'messageDropshipUnloaded' },
	},

	-- The construction vehicle is not a transport, so it counts only by its definition name.
	constructorAttachedTurret = {
		type = triggerTypes.TransportLoaded,
		parameters = {
			transportDefName = 'corvac',
			passengerDefName = 'corvacct',
		},
		actions = { 'messageConstructorAttachedTurret' },
	},

	-- Never fires: a unit name alone does not make the construction vehicle a transport.
	constructorByNameOnly = {
		type = triggerTypes.TransportLoaded,
		parameters = {
			transportName = 'constructor',
		},
		actions = { 'messageConstructorByNameOnly' },
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
				{ unitDefName = 'corvac', x = 2200, z = 2400, team = 0, unitName = 'constructor' },
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

	messageDropshipLoaded = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "The dropship loaded a unit!",
		},
	},

	messageAtlasLoadedPawn = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "An Atlas loaded a pawn!",
		},
	},

	messageDropshipUnloaded = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "The dropship unloaded the passenger!",
		},
	},

	messageConstructorAttachedTurret = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "The construction vehicle attached its turret!",
		},
	},

	messageConstructorByNameOnly = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "BUG: the construction vehicle counted as a transport by unit name alone!",
		},
	},

}

return {
	Triggers = triggers,
	Actions = actions,
}
