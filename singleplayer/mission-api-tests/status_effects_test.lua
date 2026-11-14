---
--- Status effect actions test mission.
---
--- One radar tower stands inside the effect's area, and the other outside it.
--- Each tower alone covers a patrol of enemy bots, out of sight, so they show as radar blips.
--- The western blips go and come back with the effect. The eastern blips never go.
---
--- Then an enemy jammer hides the eastern patrol, and Block Jamming over it brings the blips back.
--- Removing the eastern tower takes them away again, since Block Jamming can only hide from radar.
---

local conditionTypes = GG['MissionAPI'].ConditionDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	setup = {
		type = conditionTypes.TimeElapsed,
		parameters = {
			seconds = 1,
		},
		actions = { 'spawnTowers', 'spawnContacts', 'patrolWest', 'patrolEast', 'messageIntro' },
	},

	applyDisableRadar = {
		type = conditionTypes.TimeElapsed,
		parameters = {
			seconds = 5,
		},
		actions = { 'applyDisableRadar', 'messageApplyDisableRadar' },
	},

	clearDisableRadar = {
		type = conditionTypes.TimeElapsed,
		parameters = {
			seconds = 10,
		},
		actions = { 'clearDisableRadar', 'messageClearDisableRadar' },
	},

	applyTimedDisableRadar = {
		type = conditionTypes.TimeElapsed,
		parameters = {
			seconds = 15,
		},
		actions = { 'applyTimedDisableRadar', 'messageApplyTimedDisableRadar' },
	},

	spawnJammer = {
		type = conditionTypes.TimeElapsed,
		parameters = {
			seconds = 22,
		},
		actions = { 'fundJammer', 'spawnJammer', 'messageSpawnJammer' },
	},

	applyBlockJamming = {
		type = conditionTypes.TimeElapsed,
		parameters = {
			seconds = 27,
		},
		actions = { 'applyBlockJamming', 'messageApplyBlockJamming' },
	},

	removeEastTower = {
		type = conditionTypes.TimeElapsed,
		parameters = {
			seconds = 32,
		},
		actions = { 'removeEastTower', 'messageRemoveEastTower' },
	},
}

local actions = {

	spawnTowers = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armrad', position = { x = 1600, z = 1600 }, teamName = 'player' },
				{ unitDefName = 'armrad', position = { x = 3000, z = 1600 }, teamName = 'player', unitName = 'eastTower' },
			},
		},
	},

	spawnContacts = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'corak', position = { x = 1136, z = 2700 }, teamName = 'enemy', unitName = 'westContacts', quantity = 5, spacing = 48 },
				{ unitDefName = 'corak', position = { x = 3500, z = 2700 }, teamName = 'enemy', unitName = 'eastContacts', quantity = 5, spacing = 48 },
			},
		},
	},

	patrolWest = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'westContacts',
			orders = {
				{ CMD.PATROL, { 1136, 0, 3150 } },
			},
		},
	},

	patrolEast = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'eastContacts',
			orders = {
				{ CMD.PATROL, { 3500, 0, 3150 } },
			},
		},
	},

	messageIntro = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Two radar towers, each tracking a patrol. The western tower is inside the effect's area.",
		},
	},

	applyDisableRadar = {
		type = actionTypes.ApplyStatusEffect,
		parameters = {
			effectType = 'DisableRadar',
			effectName = 'fog',
			area = { x = 1600, z = 1600, radius = 100 },
		},
	},

	messageApplyDisableRadar = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Disable Radar applied: the western patrol drops off radar.",
		},
	},

	clearDisableRadar = {
		type = actionTypes.ClearStatusEffect,
		parameters = {
			effectName = 'fog',
		},
	},

	messageClearDisableRadar = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Disable Radar cleared: the western patrol is back on radar.",
		},
	},

	applyTimedDisableRadar = {
		type = actionTypes.ApplyStatusEffect,
		parameters = {
			effectType = 'DisableRadar',
			effectName = 'timedFog',
			area = { x = 1600, z = 1600, radius = 100 },
			duration = 5,
		},
	},

	messageApplyTimedDisableRadar = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Disable Radar applied for 5 seconds: the western patrol comes back on radar on its own.",
		},
	},

	fundJammer = {
		type = actionTypes.AddResourcesPerSecond,
		parameters = {
			teamName = 'enemy',
			energy = 50,
		},
	},

	spawnJammer = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'corjamt', position = { x = 3620, z = 2915 }, teamName = 'enemy' },
			},
		},
	},

	messageSpawnJammer = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "An enemy jammer hides the eastern patrol from radar.",
		},
	},

	applyBlockJamming = {
		type = actionTypes.ApplyStatusEffect,
		parameters = {
			effectType = 'BlockJamming',
			effectName = 'unjam',
			area = { x = 3620, z = 2915, radius = 450 },
		},
	},

	messageApplyBlockJamming = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Block Jamming applied: the eastern patrol is back on radar inside the jammer.",
		},
	},

	removeEastTower = {
		type = actionTypes.DespawnUnits,
		parameters = {
			unitName = 'eastTower',
		},
	},

	messageRemoveEastTower = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Eastern tower removed: no radar covers the patrol, so it leaves radar even under Block Jamming.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
