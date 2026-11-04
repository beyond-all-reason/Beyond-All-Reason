---
--- Status effect actions test mission.
---
--- One radar tower stands inside the effect's area, and the other outside it.
--- Open the radar view to watch the first tower's coverage go and come back.
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	setup = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 1,
		},
		actions = { 'spawnTowers', 'messageIntro' },
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
				{ unitDefName = 'armrad', x = 1800, z = 1600, teamName = 'player' },
				{ unitDefName = 'armrad', x = 2000, z = 1800, teamName = 'player' },
			},
		},
	},

	messageIntro = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Two radar towers. The one further north is inside the effect's area.",
		},
	},

	applyNoRadar = {
		type = actionTypes.ApplyStatusEffect,
		parameters = {
			effectType = 'NoRadar',
			effectName = 'fog',
			area = { x = 1800, z = 1600, radius = 100 },
		},
	},

	messageApplyNoRadar = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "No Radar applied: the northern tower loses its coverage.",
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
			messageKey = "No Radar cleared: the northern tower has its coverage back.",
		},
	},

	applyTimedNoRadar = {
		type = actionTypes.ApplyStatusEffect,
		parameters = {
			effectType = 'NoRadar',
			effectName = 'timedFog',
			area = { x = 1800, z = 1600, radius = 100 },
			duration = 5,
		},
	},

	messageApplyTimedNoRadar = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "No Radar applied for 5 seconds: the northern tower gets its coverage back on its own.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
