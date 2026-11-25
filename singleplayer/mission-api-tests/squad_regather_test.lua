---
--- Campaign AI regathering squad test mission.
---
--- Needs the campaign AI on the enemy team: tools/StartScripts/startscript_mission_api_campaign_ai_quicksilver.txt
--- with missionoptions set to the base64url of {"entryPoint":"singleplayer/mission-api-tests/squad_regather_test.lua"}:
--- eyJlbnRyeVBvaW50Ijoic2luZ2xlcGxheWVyL21pc3Npb24tYXBpLXRlc3RzL3NxdWFkX3JlZ2F0aGVyX3Rlc3QubHVhIn0=
---
--- Expected timeline, watching the messages:
---   5 s    the enemy bot lab starts on two grunts for the raiders, a squad that regathers
---   later  "assembled"; 10 s later the raiders are disbanded: "disbanded", and "assembled" again
---          within a second, from the same grunts; that happens once or twice before 70 s
---   70 s   the raiders stop regathering and are disbanded: "disbanded" is the last message
---

local conditionTypes = GG['MissionAPI'].ConditionDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	defineRaiders = {
		type = conditionTypes.TimeElapsed,
		parameters = {
			seconds = 5,
		},
		actions = { 'defineRaiders', 'regatherRaiders' },
	},

	raidersAssembled = {
		type = conditionTypes.SquadAssembled,
		settings = {
			repeating = true,
		},
		parameters = {
			squadName = 'raiders',
		},
		actions = { 'messageAssembled', 'startDisbandCountdown' },
	},

	disbandCountdownFinished = {
		type = conditionTypes.CountdownFinished,
		settings = {
			repeating = true,
			maxRepeats = 2,
		},
		parameters = {
			countdownID = 'disbandCountdown',
		},
		actions = { 'disbandRaiders' },
	},

	raidersDisbanded = {
		type = conditionTypes.SquadDisbanded,
		settings = {
			repeating = true,
		},
		parameters = {
			squadName = 'raiders',
		},
		actions = { 'messageDisbanded' },
	},

	stopRegathering = {
		type = conditionTypes.TimeElapsed,
		parameters = {
			seconds = 70,
		},
		actions = { 'stopRegatheringRaiders', 'messageStopRegathering', 'disbandRaiders' },
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
			composition = { corak = 2 },
		},
	},

	regatherRaiders = {
		type = actionTypes.EnableSquadRegather,
		parameters = {
			squadName = 'raiders',
		},
	},

	messageAssembled = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Squad regather test: the raiders have assembled.",
		},
	},

	startDisbandCountdown = {
		type = actionTypes.AddCountdown,
		parameters = {
			countdownID = 'disbandCountdown',
			seconds = 10,
		},
	},

	disbandRaiders = {
		type = actionTypes.DisbandSquad,
		parameters = {
			squadName = 'raiders',
		},
	},

	messageDisbanded = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Squad regather test: the raiders are disbanded.",
		},
	},

	stopRegatheringRaiders = {
		type = actionTypes.DisableSquadRegather,
		parameters = {
			squadName = 'raiders',
		},
	},

	messageStopRegathering = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Squad regather test: the raiders stop regathering.",
		},
	},
}

local unitLoadout = {
	{ unitDefName = 'corlab', position = { x = 4800, z = 1650 }, teamName = 'enemy' },
}

return {
	Triggers = triggers,
	Actions = actions,
	UnitLoadout = unitLoadout,
}
