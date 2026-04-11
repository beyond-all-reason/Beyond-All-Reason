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
		actions = { 'spawnFriendlyBot', 'spawnEnemyBot', 'nameFriendlyBotAlias', 'nameEnemyBotAlias' },
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
		actions = { 'spawnCapturable', 'spawnCapturer', 'nameCaptureTargetAlias' },
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

	totalUnitsKilledNamedReached = {
		type = triggerTypes.TotalUnitsKilled,
		parameters = {
			teamID = 0,
			unitName = 'enemyBot',
			quantity = 1,
		},
		actions = { 'messageTotalUnitsKilledNamed' },
	},

	totalUnitsKilledAliasReached = {
		type = triggerTypes.TotalUnitsKilled,
		parameters = {
			teamID = 0,
			unitName = 'enemyScout',
			quantity = 1,
		},
		actions = { 'messageTotalUnitsKilledAlias' },
	},

	totalUnitsLostReached = {
		type = triggerTypes.TotalUnitsLost,
		parameters = {
			teamID = 0,
			quantity = 1,
		},
		actions = { 'messageTotalUnitsLost' },
	},

	totalUnitsLostNamedReached = {
		type = triggerTypes.TotalUnitsLost,
		parameters = {
			teamID = 0,
			unitName = 'friendlyBot',
			quantity = 1,
		},
		actions = { 'messageTotalUnitsLostNamed' },
	},

	totalUnitsLostAliasReached = {
		type = triggerTypes.TotalUnitsLost,
		parameters = {
			teamID = 0,
			unitName = 'friendlyAce',
			quantity = 1,
		},
		actions = { 'messageTotalUnitsLostAlias' },
	},

	totalUnitsCapturedReached = {
		type = triggerTypes.TotalUnitsCaptured,
		parameters = {
			teamID = 0,
			quantity = 1,
		},
		actions = { 'messageTotalUnitsCaptured' },
	},

	totalUnitsCapturedNamedReached = {
		type = triggerTypes.TotalUnitsCaptured,
		parameters = {
			teamID = 0,
			unitName = 'capturableSolar',
			quantity = 1,
		},
		actions = { 'messageTotalUnitsCapturedNamed' },
	},

	totalUnitsCapturedNamedByDefReached = {
		type = triggerTypes.TotalUnitsCaptured,
		parameters = {
			teamID = 0,
			unitDefName = 'armsolar',
			unitName = 'capturePrize',
			quantity = 1,
		},
		actions = { 'messageTotalUnitsCapturedNamedByDef' },
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
			unitName = 'enemyBot',
			unitDefName = 'armpw',
			teamID = 1,
			position = { x = 1880, z = 1800 },
		},
	},

	nameFriendlyBotAlias = {
		type = actionTypes.NameUnits,
		parameters = {
			unitName = 'friendlyAce',
			teamID = 0,
			unitDefName = 'armwar',
			area = { x = 1800, z = 1800, radius = 120 },
		},
	},

	nameEnemyBotAlias = {
		type = actionTypes.NameUnits,
		parameters = {
			unitName = 'enemyScout',
			teamID = 1,
			unitDefName = 'armpw',
			area = { x = 1880, z = 1800, radius = 120 },
		},
	},

	spawnCapturable = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'capturableSolar',
			unitDefName = 'armsolar',
			teamID = 1,
			position = { x = 1800, z = 1950 },
		},
	},

	nameCaptureTargetAlias = {
		type = actionTypes.NameUnits,
		parameters = {
			unitName = 'capturePrize',
			teamID = 1,
			unitDefName = 'armsolar',
			area = { x = 1800, z = 1950, radius = 120 },
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

	messageTotalUnitsKilledNamed = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Statistics Test] TotalUnitsKilled fired for unitName enemyBot.",
		},
	},

	messageTotalUnitsKilledAlias = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Statistics Test] TotalUnitsKilled fired for alias enemyScout.",
		},
	},

	messageTotalUnitsLost = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Statistics Test] TotalUnitsLost fired: Team 0 has lost >= 1 unit.",
		},
	},

	messageTotalUnitsLostNamed = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Statistics Test] TotalUnitsLost fired for unitName friendlyBot.",
		},
	},

	messageTotalUnitsLostAlias = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Statistics Test] TotalUnitsLost fired for alias friendlyAce.",
		},
	},

	messageTotalUnitsCaptured = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Statistics Test] TotalUnitsCaptured fired: Team 0 has captured >= 1 unit.",
		},
	},

	messageTotalUnitsCapturedNamed = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Statistics Test] TotalUnitsCaptured fired for unitName capturableSolar.",
		},
	},

	messageTotalUnitsCapturedNamedByDef = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Statistics Test] TotalUnitsCaptured fired for unitName capturePrize + unitDefName armsolar.",
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
