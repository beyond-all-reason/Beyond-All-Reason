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

	unitRessed = {
		type = triggerTypes.UnitResurrected,
		parameters = {
			featureName  = 'wreck-to-resurrect',
			teamID = 0,
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
		type = actionTypes.CreateFeatures,
		parameters = {
			featureLoadout = {
				{ featureDefName = 'rocks30_def_01', x = 1800, z = 1800, facing = 's', featureName = 'theRocks' },
			},
		},
	},

	createRockToDestroy = {
		type = actionTypes.CreateFeatures,
		parameters = {
			featureLoadout = {
				{ featureDefName = 'rocks30_def_01', x = 1900, z = 1900, facing = 's', featureName = 'theRocks' },
			},
		},
	},

	createWreckToAttack = {
		type = actionTypes.CreateFeatures,
		parameters = {
			featureLoadout = {
				{ featureDefName = 'armllt_dead', x = 2000, z = 2100, facing = 'w', featureName = 'wreck-to-destroy' },
			},
		},
	},

	createWreckToResurrect = {
		type = actionTypes.CreateFeatures,
		parameters = {
			featureLoadout = {
				{ featureDefName = 'armpw_dead', x = 1900, z = 2000, facing = 'w', featureName = 'wreck-to-resurrect' },
			},
		},
	},

	spawnReclaimer = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armrectr', x = 1800, z = 1900, team = 0, unitName = 'reclaimer' },
			},
		},
	},

	spawnAttacker = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armham', x = 1800, z = 2100, team = 0, unitName = 'attacker' },
			},
		},
	},

	orderReclaimerReclaimAndRes = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'reclaimer',
			orders = {
				{ CMD.RECLAIM, { 1800, 0, 1800, 80 } },
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
		type = actionTypes.DestroyFeatures,
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
	Triggers = triggers,
	Actions  = actions,
}
