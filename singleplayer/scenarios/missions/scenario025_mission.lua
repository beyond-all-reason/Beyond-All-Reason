-- Mission script for scenario025: "First Contact"
-- Demonstrates the Mission API: timed messages, enemy reinforcement waves,
-- a victory condition tied to team destruction, and a defeat time limit.

local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes  = GG['MissionAPI'].ActionTypes

-- ============================================================
-- TRIGGERS
-- ============================================================

local triggers = {

	-- Welcome message at game start
	introMessage = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 30, -- ~1 second after start
		},
		actions = { 'msgIntro' },
	},

	-- Remind the player to expand early
	expandReminder = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 900, -- ~30 seconds
		},
		actions = { 'msgExpand' },
	},

	-- First enemy reinforcement wave
	wave1 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 1800, -- ~60 seconds
		},
		actions = { 'spawnWave1', 'msgWave1', 'orderWave1Attack' },
	},

	-- Warn about incoming second wave
	wave2Warning = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 4500, -- ~2.5 minutes
		},
		actions = { 'msgWave2Warning' },
	},

	-- Second, stronger enemy reinforcement wave
	wave2 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 5400, -- ~3 minutes
		},
		actions = { 'spawnWave2', 'msgWave2', 'orderWave2Attack' },
	},

	-- Defeat: time limit expires before victory
	timeLimitExpired = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 18000, -- ~10 minutes
		},
		actions = { 'msgTimeUp', 'defeatPlayer' },
	},

	-- Victory: enemy ally team is wiped out
	enemyTeamDestroyed = {
		type = triggerTypes.TeamDestroyed,
		parameters = {
			teamID = 1, -- enemy commander's team
		},
		actions = {
			'disableTimeLimitTrigger',
			'msgVictory',
			'victoryPlayer',
		},
	},
}

-- ============================================================
-- ACTIONS
-- ============================================================

local actions = {

	-- ---- Messages ----

	msgIntro = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Commander, an enemy has established a forward base across the river. Destroy their forces before they overwhelm us. You have 10 minutes.",
		},
	},

	msgExpand = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Secure the metal deposits along the crossing. Resources will be critical.",
		},
	},

	msgWave1 = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Incoming! Enemy scouts detected moving across the isthmus.",
		},
	},

	msgWave2Warning = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Intelligence reports a larger enemy force mobilising. Prepare your defences.",
		},
	},

	msgWave2 = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "The second wave is attacking! Hold the line!",
		},
	},

	msgTimeUp = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Time has run out. The enemy has consolidated their position. Mission failed.",
		},
	},

	msgVictory = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Outstanding work, Commander. The enemy has been neutralised. Area secured.",
		},
	},

	-- ---- Wave 1: a small scouting party (3 light bots) ----

	spawnWave1 = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName   = 'enemy-wave1',
			unitDefName = 'corak',
			teamID     = 1,
			position   = { x = 5500, z = 2500 },
			quantity   = 3,
			facing     = 'w',
			spacing    = 48,
		},
	},

	orderWave1Attack = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'enemy-wave1',
			orders = {
				{ CMD.FIGHT, { 1900, 0, 7000 }, {} },
			},
		},
	},

	-- ---- Wave 2: a heavier assault group (4 thugs) ----

	spawnWave2 = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName    = 'enemy-wave2-tanks',
			unitDefName = 'corthud',
			teamID      = 1,
			position    = { x = 5500, z = 2500 },
			quantity    = 4,
			facing      = 'w',
			spacing     = 64,
		},
	},

	orderWave2Attack = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'enemy-wave2-tanks',
			orders = {
				{ CMD.FIGHT, { 1900, 0, 7000 }, {} },
			},
		},
	},

	-- ---- Win / Loss conditions ----

	-- Disable the time-limit trigger once the player wins so it doesn't fire defeat afterwards
	disableTimeLimitTrigger = {
		type = actionTypes.DisableTrigger,
		parameters = {
			triggerID = 'timeLimitExpired',
		},
	},

	victoryPlayer = {
		type = actionTypes.Victory,
		parameters = {
			allyTeamIDs = { 0 },
		},
	},

	defeatPlayer = {
		type = actionTypes.Defeat,
		parameters = {
			allyTeamIDs = { 0 },
		},
	},
}

-- ============================================================
-- LOADOUT
-- ============================================================
-- Starting units for both teams. Defined here rather than in the scenario file
-- so that the mission script is the single source of truth for all game state.

local loadout = {
	unitloadout = {
		-- Player (team 0) starting forces
		{ name = 'armcom',   x = 2157, y = 154, z = 6976, rot = 16384,  team = 0 },
		{ name = 'armck',    x = 2100, y = 154, z = 6850, rot = 16384,  team = 0 },
		{ name = 'armck',    x = 2200, y = 154, z = 7050, rot = 16384,  team = 0 },
		{ name = 'armsolar', x = 2040, y = 154, z = 6800, rot = 16384,  team = 0 },
		{ name = 'armwin',   x = 1990, y = 154, z = 7100, rot = 16384,  team = 0 },
		{ name = 'armwin',   x = 2040, y = 154, z = 7100, rot = 16384,  team = 0 },
		{ name = 'armmex',   x = 2050, y = 154, z = 6970, rot = 16384,  team = 0 },
		{ name = 'armmex',   x = 1760, y = 154, z = 7740, rot = 16384,  team = 0 },

		-- Enemy (team 1) starting forces — forward base across the crossing
		{ name = 'corcom',   x = 4800, y = 52,  z = 3600, rot = -16384, team = 1 },
		{ name = 'corck',    x = 4750, y = 52,  z = 3200, rot = -16384, team = 1 },
		{ name = 'corck',    x = 4800, y = 52,  z = 3000, rot = -16384, team = 1 },
		{ name = 'corsolar', x = 5000, y = 52,  z = 3200, rot = 0,      team = 1 },
		{ name = 'corwin',   x = 4950, y = 52,  z = 3300, rot = 0,      team = 1 },
		{ name = 'cormex',   x = 5040, y = 52,  z = 2540, rot = 0,      team = 1 },
		{ name = 'cormex',   x = 5650, y = 52,  z = 2480, rot = 0,      team = 1 },
		{ name = 'corllt',   x = 4900, y = 52,  z = 3380, rot = -16384, team = 1 },
	},
	featureloadout = {
		-- Wreckage near the crossing — evidence of an earlier skirmish.
		{ name = 'armflea_dead',  x = 3700, y = 100, z = 4300, rot = 12000, resurrectas = 'armflea'  },
		{ name = 'armflea_dead',  x = 3850, y = 100, z = 4450, rot = 4000,  resurrectas = 'armflea'  },
		{ name = 'corak_dead',    x = 4000, y = 100, z = 4200, rot = 28000, resurrectas = 'corak'    },
		{ name = 'corak_dead',    x = 4150, y = 100, z = 4400, rot = 8000,  resurrectas = 'corak'    },
		{ name = 'armpw_dead',    x = 3900, y = 100, z = 4600, rot = 20000, resurrectas = 'armck'    },
	},
}

return {
	Triggers = triggers,
	Actions  = actions,
	Loadout  = loadout,
}
