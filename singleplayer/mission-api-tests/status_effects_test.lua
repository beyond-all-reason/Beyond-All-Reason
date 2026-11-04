---
--- Status effect actions test mission.
---
--- One radar tower stands inside the effect's area, and the other outside it.
--- Each tower alone covers a patrol of enemy bots, out of sight, so they show as radar blips.
--- The western blips go and come back with the effect. The eastern blips never go.
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	setup = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 1,
		},
		actions = { 'spawnTowers', 'spawnContacts', 'patrolWest', 'patrolEast', 'messageIntro' },
	},

	applyNoRadar = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 5,
		},
		actions = { 'applyNoRadar', 'messageApplyNoRadar' },
	},

	clearNoRadar = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 10,
		},
		actions = { 'clearNoRadar', 'messageClearNoRadar' },
	},

	applyTimedNoRadar = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 15,
		},
		actions = { 'applyTimedNoRadar', 'messageApplyTimedNoRadar' },
	},
}

local actions = {

	spawnTowers = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armrad', position = { x = 1600, z = 1600 }, teamName = 'player' },
				{ unitDefName = 'armrad', position = { x = 3000, z = 1600 }, teamName = 'player' },
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

	applyNoRadar = {
		type = actionTypes.ApplyStatusEffect,
		parameters = {
			effectType = 'NoRadar',
			effectName = 'fog',
			area = { x = 1600, z = 1600, radius = 100 },
		},
	},

	messageApplyNoRadar = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "No Radar applied: the western patrol drops off radar.",
		},
	},

	clearNoRadar = {
		type = actionTypes.ClearStatusEffect,
		parameters = {
			effectName = 'fog',
		},
	},

	messageClearNoRadar = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "No Radar cleared: the western patrol is back on radar.",
		},
	},

	applyTimedNoRadar = {
		type = actionTypes.ApplyStatusEffect,
		parameters = {
			effectType = 'NoRadar',
			effectName = 'timedFog',
			area = { x = 1600, z = 1600, radius = 100 },
			duration = 5,
		},
	},

	messageApplyTimedNoRadar = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "No Radar applied for 5 seconds: the western patrol comes back on radar on its own.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
