---
--- Campaign AI squad settings test mission.
---
--- Needs the campaign AI on the enemy team: tools/StartScripts/startscript_mission_api_campaign_ai_quicksilver.txt
--- with missionoptions set to the base64url of {"entryPoint":"singleplayer/mission-api-tests/squad_settings_test.lua"}:
--- eyJlbnRyeVBvaW50Ijoic2luZ2xlcGxheWVyL21pc3Npb24tYXBpLXRlc3RzL3NxdWFkX3NldHRpbmdzX3Rlc3QubHVhIn0=
---
--- Expected timeline, watching the enemy team:
---   5 s   the enemy bot lab starts on three grunts for the raiders
---   later the raiders assemble east of the lab, are told never to retreat, and guard the enemy
---         construction bot wherever it goes
---   30 s after they assembled, the raiders leave the bot and stand east of the lab again
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	defineRaiders = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 5,
		},
		actions = { 'defineRaiders' },
	},

	raidersAssembled = {
		type = triggerTypes.SquadAssembled,
		parameters = {
			squadName = 'raiders',
		},
		actions = { 'neverRetreat', 'escortBuilder', 'messageEscort', 'startEscortCountdown' },
	},

	escortCountdownFinished = {
		type = triggerTypes.CountdownFinished,
		parameters = {
			countdownID = 'escortCountdown',
		},
		actions = { 'defendEast', 'messageDefend' },
	},
}

local actions = {

	defineRaiders = {
		type = actionTypes.DefineSquad,
		parameters = {
			squadName = 'raiders',
			teamName = 'enemy',
			position = { x = 5000, z = 1500 },
			gatherRange = 700,
			composition = { corak = 3 },
		},
	},

	neverRetreat = {
		type = actionTypes.SetSquadRetreatThreshold,
		parameters = {
			squadName = 'raiders',
			threshold = 0,
		},
	},

	escortBuilder = {
		type = actionTypes.SetSquadEscort,
		parameters = {
			squadName = 'raiders',
			unitName = 'builder',
		},
	},

	messageEscort = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Squad settings test: the raiders escort the enemy construction bot.",
		},
	},

	startEscortCountdown = {
		type = actionTypes.AddCountdown,
		parameters = {
			countdownID = 'escortCountdown',
			seconds = 30,
		},
	},

	defendEast = {
		type = actionTypes.RunSquad,
		parameters = {
			squadName = 'raiders',
			task = 'DEFEND',
			position = { x = 5000, z = 1500 },
		},
	},

	messageDefend = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Squad settings test: the raiders leave the construction bot.",
		},
	},
}

local unitLoadout = {
	{ unitDefName = 'corlab', position = { x = 4800, z = 1650 }, teamName = 'enemy' },
	{ unitDefName = 'corck', unitName = 'builder', position = { x = 4700, z = 1500 }, teamName = 'enemy' },
}

return {
	Triggers = triggers,
	Actions = actions,
	UnitLoadout = unitLoadout,
}
