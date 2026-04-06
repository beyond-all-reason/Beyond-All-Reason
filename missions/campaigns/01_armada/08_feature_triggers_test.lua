local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local lobbyData = {
	missionId = "feature_triggers_test",
	title = "Feature Triggers Test",
	description = "Tests triggers related to features, including creation, destruction, reclamation, and resurrection.",
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

	spawnFeatures = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 30,
		},
		actions = { 'createRockToReclaim', 'createRockToDestroy', 'createWreckToResurrect', 'createWreckToAttack', 'spawnReclaimer', 'spawnAttacker', 'orderAttackerDestroyWreck' },
	},

	orderReclaimerReclaimAndRes = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 60,
		},
		-- for some reason, CMD.RESURRECT doesn't work in the same frame as its target is spawned
		actions = { 'orderReclaimerReclaimAndRes' },
	},

	destroyRocks = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 150,
		},
		actions = { 'destroyRocks' },
	},

	rockCreated = {
		type = triggerTypes.FeatureCreated,
		parameters = {
			featureDefName = 'rocks30_def_01',
			area = { x1 = 1600, z1 = 1500, x2 = 2200, z2 = 2100 },
		},
		actions = { 'messageRocksCreated' },
	},

	rockReclaimed = {
		type = triggerTypes.FeatureReclaimed,
		parameters = {
			featureName = 'theRocks',
			teamName = 'thePlayerTeam',
		},
		actions = { 'messageRockReclaimed' },
	},

	rockDestroyed = {
		type = triggerTypes.FeatureDestroyed,
		parameters = {
			featureName = 'theRocks',
		},
		actions = { 'messageRockDestroyed' },
	},

	unitRessed = {
		type = triggerTypes.UnitResurrected,
		parameters = {
			featureName = 'wreck-to-resurrect',
			teamName    = 'thePlayerTeam',
		},
		actions = { 'messageWreckResurrected' },
	},

	wreckDestroyed = {
		type = triggerTypes.FeatureDestroyed,
		parameters = {
			featureName = 'wreck-to-destroy',
		},
		actions = { 'messageWreckDestroyed' },
	},

	wreckDestroyedInZone = {
		type = triggerTypes.FeatureDestroyed,
		parameters = {
			featureDefName = 'armllt_dead',
			area = { x = 2000, z = 2100, radius = 200 },
		},
		actions = { 'messageWreckDestroyedInZone' },
	},
}

local actions = {

	createRockToReclaim = {
		type = actionTypes.CreateFeature,
		parameters = {
			featureName    = 'theRocks',
			featureDefName = 'rocks30_def_01',
			position       = { x = 1800, z = 1800 },
			facing         = 's',
		},
	},

	createRockToDestroy = {
		type = actionTypes.CreateFeature,
		parameters = {
			featureName    = 'theRocks',
			featureDefName = 'rocks30_def_01',
			position       = { x = 1900, z = 1900 },
			facing         = 's',
		},
	},

	createWreckToAttack = {
		type = actionTypes.CreateFeature,
		parameters = {
			featureName    = 'wreck-to-destroy',
			featureDefName = 'armllt_dead',
			position       = { x = 2000, z = 2100 },
			facing         = 'w',
		},
	},

	createWreckToResurrect = {
		type = actionTypes.CreateFeature,
		parameters = {
			featureName    = 'wreck-to-resurrect',
			featureDefName = 'armpw_dead',
			position       = { x = 1900, z = 2000 },
			facing         = 'w',
		},
	},

	spawnReclaimer = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName    = 'reclaimer',
			unitDefName = 'armrectr',
			teamName    = 'thePlayerTeam',
			position    = { x = 1800, z = 1900 },
		},
	},

	spawnAttacker = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName    = 'attacker',
			unitDefName = 'armham',
			teamName    = 'thePlayerTeam',
			position    = { x = 1800, z = 2100 },
		},
	},

	orderReclaimerReclaimAndRes = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'reclaimer',
			orders = {
				{ CMD.RECLAIM,   { 1800, 0, 1800, 80 } },
				{ CMD.RESURRECT, { 1900, 0, 2000, 80 }, { 'shift' } },
			},
		},
	},

	orderAttackerDestroyWreck = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'attacker',
			orders = {
				{ CMD.ATTACK, { 2000, 0, 2100 } },
			},
		},
	},

	destroyRocks = {
		type = actionTypes.DestroyFeature,
		parameters = {
			featureName = 'theRocks',
		},
	},

	messageRocksCreated = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Feature Test] Rocks were created in the area.",
		},
	},

	messageRockReclaimed = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Feature Test] Named rock was reclaimed.",
		},
	},

	messageRockDestroyed = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Feature Test] Named rock was destroyed.",
		},
	},

	messageWreckResurrected = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Feature Test] Named wreck was resurrected.",
		},
	},

	messageWreckDestroyed = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Feature Test] Named wreck was destroyed.",
		},
	},

	messageWreckDestroyedInZone = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Feature Test] An armllt wreck was destroyed inside the zone.",
		},
	},
}

return {
	LobbyData   = lobbyData,
	StartScript = startScript,
	Triggers    = triggers,
	Actions     = actions,
}
