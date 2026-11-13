---
--- Campaign AI production test mission.
---
--- Needs the campaign AI on the enemy team: tools/StartScripts/startscript_mission_api_campaign_ai_quicksilver.txt
--- with missionoptions set to the base64url of {"entryPoint":"singleplayer/mission-api-tests/production_test.lua"}:
--- eyJlbnRyeVBvaW50Ijoic2luZ2xlcGxheWVyL21pc3Npb24tYXBpLXRlc3RzL3Byb2R1Y3Rpb25fdGVzdC5sdWEifQ==
---
--- Expected timeline, watching the enemy bot lab:
---   start  the lab builds the AI's own fighters
---   60 s   production is disabled: the lab builds no more fighters for the AI, only construction
---          and resurrection bots
---   75 s   a squad of two thugs is defined, and the lab builds those two all the same
---   150 s  production is enabled again: the lab builds the AI's own fighters again
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	disableProduction = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 60,
		},
		actions = { 'disableProduction', 'messageDisableProduction' },
	},

	defineReserves = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 75,
		},
		actions = { 'defineReserves' },
	},

	reservesAssembled = {
		type = triggerTypes.SquadAssembled,
		parameters = {
			squadName = 'reserves',
		},
		actions = { 'messageReservesAssembled' },
	},

	enableProduction = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 150,
		},
		actions = { 'enableProduction', 'messageEnableProduction' },
	},
}

local actions = {

	disableProduction = {
		type = actionTypes.DisableProduction,
		parameters = {
			unitName = 'enemyLab',
			teamName = 'enemy',
		},
	},

	messageDisableProduction = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Production test: the enemy lab stops building fighters for the AI's own army.",
		},
	},

	defineReserves = {
		type = actionTypes.DefineSquad,
		parameters = {
			squadName = 'reserves',
			teamName = 'enemy',
			position = { x = 5000, z = 1500 },
			gatherRange = 700,
			composition = { corthud = 2 },
		},
	},

	messageReservesAssembled = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Production test: the lab built the squad's two thugs all the same.",
		},
	},

	enableProduction = {
		type = actionTypes.EnableProduction,
		parameters = {
			unitName = 'enemyLab',
			teamName = 'enemy',
		},
	},

	messageEnableProduction = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Production test: the enemy lab builds fighters for the AI's own army again.",
		},
	},
}

local unitLoadout = {
	{ unitDefName = 'corlab', unitName = 'enemyLab', position = { x = 4800, z = 1650 }, teamName = 'enemy' },
}

return {
	Triggers = triggers,
	Actions = actions,
	UnitLoadout = unitLoadout,
}
