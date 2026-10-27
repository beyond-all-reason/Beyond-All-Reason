local eventTypes = GG['MissionAPI'].ConditionDefinitions.EventTypes
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local SILO = { 1400, 0, 2600 }
local CITADEL = { 6000, 0, 5400 }

local EMPTY_GROUND = { 2000, 0, 5800 }
local SILO_TARGETS = {
	{ 6000, 0, 5400 },
	{ 6024, 0, 5400 },
	{ 5976, 0, 5400 },
	{ 6000, 0, 5424 },
	{ 6000, 0, 5376 },
}

local REACTION_SECONDS = 4 -- ish
local FIRST_NUKE_SECONDS = 9 + 13
local SALVO_SECONDS = 9 + 4 * 30 + 9

local function trackedUnitID(unitName)
	return next(GG['MissionAPI'].trackedUnitIDs[unitName] or {})
end

local triggers = {
	spawnSilo = {
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 2,
		},
		actions = { 'fundSilo', 'spawnSilo', 'messageSpawnSilo' },
	},

	firstNukeHalfBuilt = {
		type = eventTypes.StockpileProgress,
		parameters = {
			unitName = 'silo',
			progress = 0.5,
		},
		actions = { 'messageFirstNukeHalfBuilt' },
	},

	firstNukeStocked = {
		type = eventTypes.StockpileCount,
		parameters = {
			unitName = 'silo',
			count = 1,
		},
		actions = { 'messageFirstNukeStocked', 'waitToLaunchFirstNuke' },
	},

	launchFirstNuke = {
		type = eventTypes.CountdownFinished,
		parameters = {
			countdownID = 'launchFirstNuke',
		},
		actions = { 'launchFirstNuke', 'messageLaunchFirstNuke', 'waitForFirstNuke' },
	},

	spawnCitadel = {
		type = eventTypes.CountdownFinished,
		parameters = {
			countdownID = 'firstNukeLanded',
		},
		actions = { 'spawnCitadel', 'stockCitadel', 'nearlyStockFiveNukes', 'messageSpawnCitadel' },
	},

	fiveNukesStocked = {
		type = eventTypes.StockpileCount,
		parameters = {
			unitName = 'silo',
			count = 5,
		},
		actions = { 'messageFiveNukesStocked', 'waitToLaunchFiveNukes' },
	},

	launchFiveNukes = {
		type = eventTypes.CountdownFinished,
		parameters = {
			countdownID = 'launchFiveNukes',
		},
		actions = { 'launchFiveNukes', 'messageLaunchFiveNukes', 'waitForFiveNukes' },
	},

	fiveNukesIntercepted = {
		type = eventTypes.CountdownFinished,
		parameters = {
			countdownID = 'fiveNukesIntercepted',
		},
		actions = { 'messageFiveNukesIntercepted', 'victory' },
	},
}

local actions = {
	fundSilo = {
		type = actionTypes.AddResourcesPerSecond,
		parameters = {
			teamID = 0,
			metal = 10,
			energy = 1100,
		},
	},

	spawnSilo = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armsilo', x = SILO[1], z = SILO[3], team = 0, unitName = 'silo' },
			},
		},
	},

	messageSpawnSilo = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = 'An Armageddon is stockpiling its first nuke.',
		},
	},

	messageFirstNukeHalfBuilt = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = 'The Armageddon is halfway through its first nuke.',
		},
	},

	messageFirstNukeStocked = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = 'The Armageddon has a nuke stocked.',
		},
	},

	waitToLaunchFirstNuke = {
		type = actionTypes.AddCountdown,
		parameters = {
			countdownID = 'launchFirstNuke',
			seconds = REACTION_SECONDS,
			displayed = false,
		},
	},

	launchFirstNuke = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'silo',
			orders = {
				{ CMD.ATTACK, EMPTY_GROUND },
			},
		},
	},

	messageLaunchFirstNuke = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = 'The Armageddon launches its nuke at empty ground.',
		},
	},

	waitForFirstNuke = {
		type = actionTypes.AddCountdown,
		parameters = {
			countdownID = 'firstNukeLanded',
			seconds = FIRST_NUKE_SECONDS + REACTION_SECONDS,
			displayed = false,
		},
	},

	spawnCitadel = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armamd', x = CITADEL[1], z = CITADEL[3], team = 1, unitName = 'citadel' },
			},
		},
	},

	-- Stocking an interceptor takes 90 s, so the Citadel starts with enough for all five nukes.
	stockCitadel = {
		type = actionTypes.Custom,
		parameters = {
			['function'] = function()
				Spring.SetUnitStockpile(trackedUnitID('citadel'), 5, 0)
			end,
		},
	},

	nearlyStockFiveNukes = {
		type = actionTypes.Custom,
		parameters = {
			['function'] = function()
				Spring.SetUnitStockpile(trackedUnitID('silo'), 4, 0.9)
			end,
		},
	},

	messageSpawnCitadel = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = 'The enemy has a Citadel with five interceptors. The Armageddon skips ahead to four nukes, with the fifth almost done.',
		},
	},

	messageFiveNukesStocked = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = 'The Armageddon has five nukes stocked.',
		},
	},

	waitToLaunchFiveNukes = {
		type = actionTypes.AddCountdown,
		parameters = {
			countdownID = 'launchFiveNukes',
			seconds = REACTION_SECONDS,
			displayed = false,
		},
	},

	launchFiveNukes = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'silo',
			orders = {
				{ CMD.ATTACK, SILO_TARGETS[1] },
				{ CMD.ATTACK, SILO_TARGETS[2], { 'shift' } },
				{ CMD.ATTACK, SILO_TARGETS[3], { 'shift' } },
				{ CMD.ATTACK, SILO_TARGETS[4], { 'shift' } },
				{ CMD.ATTACK, SILO_TARGETS[5], { 'shift' } },
			},
		},
	},

	messageLaunchFiveNukes = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = 'The Armageddon launches all five nukes at the Citadel, one per reload.',
		},
	},

	waitForFiveNukes = {
		type = actionTypes.AddCountdown,
		parameters = {
			countdownID = 'fiveNukesIntercepted',
			seconds = SALVO_SECONDS,
			displayed = false,
		},
	},

	messageFiveNukesIntercepted = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = 'The Citadel intercepted some of those five nukes, probably.',
		},
	},

	victory = {
		type = actionTypes.Victory,
		parameters = {
			allyTeamIDs = { 0 },
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
