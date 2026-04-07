---
--- Statistics triggers test mission.
---

local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local triggers = {

	-- ── Spawns ────────────────────────────────────────────────────────────────

	spawnBots = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 30,
		},
		actions = { 'spawnFriendlyBot', 'spawnEnemyBot' },
	},

	killFriendlyBot = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 180,
		},
		actions = { 'killFriendlyBot' },
	},

	spawnCapture = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 240,
		},
		actions = { 'spawnCapturable', 'spawnCapturer' },
	},

	orderCapture = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 270,
		},
		actions = { 'orderCapture' },
	},

	spawnBuilders = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 510,
		},
		actions = { 'spawnConstructor', 'orderBuild' },
	},

	-- ── Statistics triggers ───────────────────────────────────────────────────

	totalUnitsKilledReached = {
		type = triggerTypes.TotalUnitsKilled,
		parameters = {
			teamID = 0,
			quantity = 1,
		},
		actions = { 'messageTotalUnitsKilled' },
	},

	totalUnitsLostReached = {
		type = triggerTypes.TotalUnitsLost,
		parameters = {
			teamID = 0,
			quantity = 1,
		},
		actions = { 'messageTotalUnitsLost' },
	},

	totalUnitsCapturedReached = {
		type = triggerTypes.TotalUnitsCaptured,
		parameters = {
			teamID = 0,
			quantity = 1,
		},
		actions = { 'messageTotalUnitsCaptured' },
	},

	totalUnitsBuiltReached = {
		type = triggerTypes.TotalUnitsBuilt,
		parameters = {
			teamID = 0,
			quantity = 1,
		},
		actions = { 'messageTotalUnitsBuilt' },
	},
}

local actions = {

	-- ── Spawn ─────────────────────────────────────────────────────────────────

	spawnFriendlyBot = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'friendlyBot',
			unitDefName = 'armwar',
			teamID = 0,
			position = { x = 1800, z = 1800 },
		},
	},

	spawnEnemyBot = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitDefName = 'armpw',
			teamID = 1,
			position = { x = 1880, z = 1800 },
		},
	},

	spawnCapturable = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitDefName = 'armsolar',
			teamID = 1,
			position = { x = 1800, z = 1950 },
		},
	},

	spawnCapturer = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'capturer',
			unitDefName = 'armdecom',
			teamID = 0,
			position = { x = 1900, z = 2000 },
		},
	},

	spawnConstructor = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'constructor',
			unitDefName = 'armck',
			teamID = 0,
			position = { x = 1850, z = 2100 },
			quantity = 4,
		},
	},

	-- ── Orders ────────────────────────────────────────────────────────────────

	orderCapture = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'capturer',
			orders = {
				{ CMD.FIRE_STATE, CMD.FIRESTATE_HOLDFIRE },
				{ CMD.CAPTURE, { 1800, 0, 1900, 200 } },
			},
		},
	},

	orderBuild = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'constructor',
			orders = {
				{ 'armwin', { 1950, 0, 2100 } },
			},
		},
	},

	killFriendlyBot = {
		type = actionTypes.DespawnUnits,
		parameters = {
			unitName = 'friendlyBot',
		},
	},

	-- ── Statistics trigger messages ───────────────────────────────────────────

	messageTotalUnitsKilled = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Statistics Test] TotalUnitsKilled fired: Team 0 has killed >= 1 unit.",
		},
	},

	messageTotalUnitsLost = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Statistics Test] TotalUnitsLost fired: Team 0 has lost >= 1 unit.",
		},
	},

	messageTotalUnitsCaptured = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Statistics Test] TotalUnitsCaptured fired: Team 0 has captured >= 1 unit.",
		},
	},

	messageTotalUnitsBuilt = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Statistics Test] TotalUnitsBuilt fired: Team 0 has built >= 1 unit.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
