---
--- Campaign AI actions test mission.
---
--- Needs a start script that puts the campaign AI on the enemy team:
--- tools/StartScripts/startscript_mission_api_campaign_ai_quicksilver.txt
---
--- Expected timeline, watching the enemy team:
---   start  the AI is passive: its commander and construction bot stand still
---   20 s   the AI plays normally, but builds no solar collectors or wind turbines
---   50 s   it may build solar collectors and wind turbines again
---   70 s   the three grunts walk east across the base and stay there
---   100 s  the grunts are the AI's again and leave
---   115 s  the AI is inactive: its units finish their orders and get no new ones
---   130 s  the AI is active again
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	-- Fires while the loadout spawns, before the engine has created the AI.
	constructorSpawned = {
		type = triggerTypes.UnitExists,
		parameters = {
			unitDefName = 'corck',
			teamName = 'enemy',
		},
		actions = { 'setPassive' },
	},

	intro = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 1,
		},
		actions = { 'messageIntro' },
	},

	wakeUp = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 20,
		},
		actions = { 'disableSolar', 'disableWind', 'setNormal', 'messageWakeUp' },
	},

	allowEnergy = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 50,
		},
		actions = { 'enableSolar', 'enableWind', 'messageAllowEnergy' },
	},

	takeGuards = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 70,
		},
		actions = { 'disableGuardsControl', 'moveGuards', 'messageTakeGuards' },
	},

	returnGuards = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 100,
		},
		actions = { 'enableGuardsControl', 'messageReturnGuards' },
	},

	deactivate = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 115,
		},
		actions = { 'deactivateAI', 'messageDeactivate' },
	},

	activate = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 130,
		},
		actions = { 'activateAI', 'messageActivate' },
	},
}

local actions = {

	setPassive = {
		type = actionTypes.SetAiState,
		parameters = {
			state = 'PASSIVE',
			teamName = 'enemy',
		},
	},

	messageIntro = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Campaign AI test: the enemy AI was set passive before the game started and stands still until 20 s.",
		},
	},

	disableSolar = {
		type = actionTypes.DisableUnitDef,
		parameters = {
			unitDefName = 'corsolar',
			teamName = 'enemy',
		},
	},

	disableWind = {
		type = actionTypes.DisableUnitDef,
		parameters = {
			unitDefName = 'corwin',
			teamName = 'enemy',
		},
	},

	setNormal = {
		type = actionTypes.SetAiState,
		parameters = {
			state = 'NORMAL',
			teamName = 'enemy',
		},
	},

	messageWakeUp = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "The AI plays normally now, without solar collectors or wind turbines.",
		},
	},

	enableSolar = {
		type = actionTypes.EnableUnitDef,
		parameters = {
			unitDefName = 'corsolar',
			teamName = 'enemy',
		},
	},

	enableWind = {
		type = actionTypes.EnableUnitDef,
		parameters = {
			unitDefName = 'corwin',
			teamName = 'enemy',
		},
	},

	messageAllowEnergy = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "The AI may build solar collectors and wind turbines again.",
		},
	},

	disableGuardsControl = {
		type = actionTypes.DisableUnitsControl,
		parameters = {
			unitName = 'guards',
			teamName = 'enemy',
		},
	},

	moveGuards = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'guards',
			orders = {
				{ CMD.MOVE, { 5000, 0, 1400 } },
			},
		},
	},

	messageTakeGuards = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "The mission took the three grunts from the AI and sent them east across the base, where they stay.",
		},
	},

	enableGuardsControl = {
		type = actionTypes.EnableUnitsControl,
		parameters = {
			unitName = 'guards',
			teamName = 'enemy',
		},
	},

	messageReturnGuards = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "The grunts are the AI's again.",
		},
	},

	deactivateAI = {
		type = actionTypes.DeactivateAI,
		parameters = {
			teamName = 'enemy',
		},
	},

	messageDeactivate = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "The AI is inactive: its units get no new orders.",
		},
	},

	activateAI = {
		type = actionTypes.ActivateAI,
		parameters = {
			teamName = 'enemy',
		},
	},

	messageActivate = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "The AI is active again.",
		},
	},
}

local unitLoadout = {
	{ unitDefName = 'corck', position = { x = 4500, z = 1700 }, teamName = 'enemy' },
	{ unitDefName = 'corak', position = { x = 4300, z = 1600 }, teamName = 'enemy', unitName = 'guards' },
	{ unitDefName = 'corak', position = { x = 4300, z = 1650 }, teamName = 'enemy', unitName = 'guards' },
	{ unitDefName = 'corak', position = { x = 4300, z = 1700 }, teamName = 'enemy', unitName = 'guards' },
}

return {
	Triggers = triggers,
	Actions = actions,
	UnitLoadout = unitLoadout,
}
