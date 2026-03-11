---
--- Feature triggers test mission.
---

local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local triggers = {

	spawnFeatures = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 30,
		},
		actions = { 'spawnReclaimer', 'spawnAttacker', 'createRock1', 'createRock2', 'createWreck', 'orderAttackerDestroyWreck' },
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
		actions = { 'messageRocksCreated', 'orderReclaimerReclaimRock' },
	},

	rockReclaimed = {
		type = triggerTypes.FeatureReclaimed,
		parameters = {
			featureName = 'theRocks',
			teamID = 0,
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

	wreckDestroyed = {
		type = triggerTypes.FeatureDestroyed,
		parameters = {
			featureName = 'theWreck',
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

	createRock1 = {
		type = actionTypes.CreateFeature,
		parameters = {
			featureName  = 'theRocks',
			featureDefName = 'rocks30_def_01',
			position = { x = 1800, z = 1800 },
			facing   = 's',
		},
	},

	createRock2 = {
		type = actionTypes.CreateFeature,
		parameters = {
			featureName  = 'theRocks',
			featureDefName = 'rocks30_def_01',
			position = { x = 1900, z = 1900 },
			facing   = 's',
		},
	},

	createWreck = {
		type = actionTypes.CreateFeature,
		parameters = {
			featureName  = 'theWreck',
			featureDefName = 'armllt_dead',
			position = { x = 2000, z = 2100 },
			facing   = 'w',
		},
	},

	spawnReclaimer = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName    = 'reclaimer',
			unitDefName = 'armrectr',
			teamID      = 0,
			position    = { x = 1800, z = 1900 },
		},
	},

	spawnAttacker = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName    = 'attacker',
			unitDefName = 'armham',
			teamID      = 0,
			position    = { x = 1800, z = 2100 },
		},
	},

	orderReclaimerReclaimRock = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'reclaimer',
			orders = {
				{ CMD.RECLAIM, { 1800, 0, 1800, 80 } },
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
	Triggers = triggers,
	Actions  = actions,
}
