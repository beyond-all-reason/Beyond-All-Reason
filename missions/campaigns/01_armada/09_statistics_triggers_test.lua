---
--- Statistics triggers test mission.
---

local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local lobbyData = {
	missionId = "statistics_triggers_test",
	title = "Statistics Triggers Test",
	description = "Tests triggers related to unit statistics: TotalUnitsKilled, TotalUnitsLost, TotalUnitsCaptured, TotalUnitsBuilt, and UnitsOwned.",
	unlocked = true,
}

local startScript = {
	mapName = "Quicksilver Remake 1.24",
	startPosType = 'chooseBeforeGame',
	allyTeams = {
		thePlayerAllyTeam = {
			teams = {
				thePlayerTeam = {
					name = "TestPlayer",
					Side = 'Cortex',
					StartPosX = 2200,
					StartPosZ = 1500,
				},
			},
		},
		theEnemyAllyTeam = {
			teams = {
				theEnemyTeam = {
					name = "Mission Bots",
					Side = 'Armada',
					StartPosX = 3000,
					StartPosZ = 2400,
					ai = "NullAI",
				},
			}
		},
	},
}

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
			teamName = 'thePlayerTeam',
			quantity = 1,
		},
		actions = { 'messageTotalUnitsKilled' },
	},

	totalUnitsKilledNamedReached = {
		type = triggerTypes.TotalUnitsKilled,
		parameters = {
			teamName = 'thePlayerTeam',
			unitName = 'enemyBot',
			quantity = 1,
		},
		actions = { 'messageTotalUnitsKilledNamed' },
	},

	totalUnitsKilledAliasReached = {
		type = triggerTypes.TotalUnitsKilled,
		parameters = {
			teamName = 'thePlayerTeam',
			unitName = 'enemyScout',
			quantity = 1,
		},
		actions = { 'messageTotalUnitsKilledAlias' },
	},

	totalUnitsLostReached = {
		type = triggerTypes.TotalUnitsLost,
		parameters = {
			teamName = 'thePlayerTeam',
			quantity = 1,
		},
		actions = { 'messageTotalUnitsLost' },
	},

	totalUnitsLostNamedReached = {
		type = triggerTypes.TotalUnitsLost,
		parameters = {
			teamName = 'thePlayerTeam',
			unitName = 'friendlyBot',
			quantity = 1,
		},
		actions = { 'messageTotalUnitsLostNamed' },
	},

	totalUnitsLostAliasReached = {
		type = triggerTypes.TotalUnitsLost,
		parameters = {
			teamName = 'thePlayerTeam',
			unitName = 'friendlyAce',
			quantity = 1,
		},
		actions = { 'messageTotalUnitsLostAlias' },
	},

	totalUnitsCapturedReached = {
		type = triggerTypes.TotalUnitsCaptured,
		parameters = {
			teamName = 'thePlayerTeam',
			quantity = 1,
		},
		actions = { 'messageTotalUnitsCaptured' },
	},

	totalUnitsCapturedNamedReached = {
		type = triggerTypes.TotalUnitsCaptured,
		parameters = {
			teamName = 'thePlayerTeam',
			unitName = 'capturableSolar',
			quantity = 1,
		},
		actions = { 'messageTotalUnitsCapturedNamed' },
	},

	totalUnitsCapturedNamedByDefReached = {
		type = triggerTypes.TotalUnitsCaptured,
		parameters = {
			teamName = 'thePlayerTeam',
			unitDefName = 'armsolar',
			unitName = 'capturePrize',
			quantity = 1,
		},
		actions = { 'messageTotalUnitsCapturedNamedByDef' },
	},

	totalUnitsBuiltReached = {
		type = triggerTypes.TotalUnitsBuilt,
		parameters = {
			teamName = 'thePlayerTeam',
			quantity = 1,
		},
		actions = { 'messageTotalUnitsBuilt' },
	},

	-- ── UnitsOwned triggers ───────────────────────────────────────────────────

	unitsOwnedReached = {
		type = triggerTypes.UnitsOwned,
		parameters = {
			teamName = 'thePlayerTeam',
			quantity = 1,
		},
		actions = { 'messageUnitsOwned' },
	},

	unitsOwnedByNameReached = {
		type = triggerTypes.UnitsOwned,
		parameters = {
			teamName = 'thePlayerTeam',
			unitName = 'friendlyBot',
			quantity = 1,
		},
		actions = { 'messageUnitsOwnedByName' },
	},

	unitsOwnedByDefReached = {
		type = triggerTypes.UnitsOwned,
		parameters = {
			teamName = 'thePlayerTeam',
			unitDefName = 'armck',
			quantity = 4,
		},
		actions = { 'messageUnitsOwnedByDef' },
	},

	-- Repeating: fires at 2 armck owned, then again at 4 armck owned.
	-- The same message appearing twice in the log confirms milestone advancement
	-- without re-firing at an already-passed milestone.
	unitsOwnedByDefRepeating = {
		type = triggerTypes.UnitsOwned,
		settings = {
			repeating = true,
		},
		parameters = {
			teamName = 'thePlayerTeam',
			unitDefName = 'armck',
			quantity = 2,
		},
		actions = { 'messageUnitsOwnedByDefRepeating' },
	},

	unitsOwnedByNameAndDefReached = {
		type = triggerTypes.UnitsOwned,
		parameters = {
			teamName = 'thePlayerTeam',
			unitName = 'friendlyBot',
			unitDefName = 'armwar',
			quantity = 1,
		},
		actions = { 'messageUnitsOwnedByNameAndDef' },
	},
}

local actions = {

	-- ── Spawn ─────────────────────────────────────────────────────────────────

	spawnFriendlyBot = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armwar', x = 1800, z = 1800, teamName = 'thePlayerTeam', unitName = 'friendlyBot' },
			},
		},
	},

	spawnEnemyBot = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armpw', x = 1880, z = 1800, teamName = 'theEnemyTeam', unitName = 'enemyBot' },
			},
		},
	},

	nameFriendlyBotAlias = {
		type = actionTypes.NameUnits,
		parameters = {
			unitName = 'friendlyAce',
			teamName = 'thePlayerTeam',
			unitDefName = 'armwar',
			area = { x = 1800, z = 1800, radius = 120 },
		},
	},

	nameEnemyBotAlias = {
		type = actionTypes.NameUnits,
		parameters = {
			unitName = 'enemyScout',
			teamName = 'theEnemyTeam',
			unitDefName = 'armpw',
			area = { x = 1880, z = 1800, radius = 120 },
		},
	},

	spawnCapturable = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armsolar', x = 1800, z = 1950, teamName = 'theEnemyTeam', unitName = 'capturableSolar' },
			},
		},
	},

	nameCaptureTargetAlias = {
		type = actionTypes.NameUnits,
		parameters = {
			unitName = 'capturePrize',
			teamName = 'theEnemyTeam',
			unitDefName = 'armsolar',
			area = { x = 1800, z = 1950, radius = 120 },
		},
	},

	spawnCapturer = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armdecom', x = 1900, z = 2000, teamName = 'thePlayerTeam', unitName = 'capturer' },
			},
		},
	},

	spawnConstructor = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armck', x = 1850, z = 2100, teamName = 'thePlayerTeam', unitName = 'constructor', quantity = 4 },
			},
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

	-- ── UnitsOwned trigger messages ───────────────────────────────────────────

	messageUnitsOwned = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Statistics Test] UnitsOwned fired: Team 0 owns >= 1 unit.",
		},
	},

	messageUnitsOwnedByName = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Statistics Test] UnitsOwned fired for unitName friendlyBot.",
		},
	},

	messageUnitsOwnedByDef = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Statistics Test] UnitsOwned fired for unitDefName armck x4.",
		},
	},

	messageUnitsOwnedByDefRepeating = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Statistics Test] UnitsOwned repeating fired for unitDefName armck (milestone x2 each).",
		},
	},

	messageUnitsOwnedByNameAndDef = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Statistics Test] UnitsOwned fired for unitName friendlyBot + unitDefName armwar.",
		},
	},
}

return {
	LobbyData   = lobbyData,
	StartScript = startScript,
	Triggers = triggers,
	Actions = actions,
}
