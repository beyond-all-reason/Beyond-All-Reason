---
--- Campaign AI repeating squad test mission.
---
--- Needs the campaign AI on the enemy team: tools/StartScripts/startscript_mission_api_campaign_ai_quicksilver.txt
--- with missionoptions set to the base64url of {"entryPoint":"singleplayer/mission-api-tests/squad_repeat_test.lua"}:
--- eyJlbnRyeVBvaW50Ijoic2luZ2xlcGxheWVyL21pc3Npb24tYXBpLXRlc3RzL3NxdWFkX3JlcGVhdF90ZXN0Lmx1YSJ9
---
--- Expected timeline, watching the messages:
---   5 s    the enemy bot lab starts on two grunts for the raiders, a squad that repeats
---   later  "assembled"; 10 s later the raiders are disbanded: "disbanded", and "assembled" again
---          within a second, from the same grunts; that happens once or twice before 70 s
---   70 s   the raiders stop repeating and are disbanded: "disbanded" is the last message
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	defineRaiders = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 5,
		},
		actions = { 'defineRaiders', 'repeatRaiders' },
	},

	raidersAssembled = {
		type = triggerTypes.SquadAssembled,
		settings = {
			repeating = true,
		},
		parameters = {
			squadName = 'raiders',
		},
		actions = { 'messageAssembled', 'startDisbandCountdown' },
	},

	disbandCountdownFinished = {
		type = triggerTypes.CountdownFinished,
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
		type = triggerTypes.SquadDisbanded,
		settings = {
			repeating = true,
		},
		parameters = {
			squadName = 'raiders',
		},
		actions = { 'messageDisbanded' },
	},

	stopRepeating = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 70,
		},
		actions = { 'stopRepeatingRaiders', 'messageStopRepeating', 'disbandRaiders' },
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

	repeatRaiders = {
		type = actionTypes.EnableSquadRepeat,
		parameters = {
			squadName = 'raiders',
		},
	},

	messageAssembled = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Squad repeat test: the raiders have assembled.",
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
			messageKey = "Squad repeat test: the raiders are disbanded.",
		},
	},

	stopRepeatingRaiders = {
		type = actionTypes.DisableSquadRepeat,
		parameters = {
			squadName = 'raiders',
		},
	},

	messageStopRepeating = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Squad repeat test: the raiders stop repeating.",
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
