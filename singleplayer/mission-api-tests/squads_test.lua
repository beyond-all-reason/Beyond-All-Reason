---
--- Campaign AI squads test mission.
---
--- Needs the campaign AI on the enemy team: tools/StartScripts/startscript_mission_api_campaign_ai_quicksilver.txt
--- with missionoptions set to the base64url of {"entryPoint":"singleplayer/mission-api-tests/squads_test.lua"}:
--- eyJlbnRyeVBvaW50Ijoic2luZ2xlcGxheWVyL21pc3Npb24tYXBpLXRlc3RzL3NxdWFkc190ZXN0Lmx1YSJ9
---
--- Expected timeline, watching the enemy team:
---   5 s   the enemy bot lab starts on three grunts for the raiders, with four thugs for the reserves queued
---   15 s  the reserves are cancelled: the lab builds no thugs, and no message says a squad has disbanded
---   later the three grunts stand together east of the lab, and a message says the raiders have assembled
---         the raiders then walk west past the lab and stay near the west end of the enemy plateau
---   30 s after they assembled, the raiders are disbanded, and a message says a squad has disbanded
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	defineSquads = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 5,
		},
		actions = { 'defineRaiders', 'defineReserves', 'messageDefineSquads' },
	},

	cancelReserves = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 15,
		},
		actions = { 'cancelReserves', 'messageCancelReserves' },
	},

	raidersAssembled = {
		type = triggerTypes.SquadAssembled,
		parameters = {
			squadName = 'raiders',
		},
		actions = { 'messageRaidersAssembled', 'runRaiders', 'startRaidersCountdown' },
	},

	raidersCountdownFinished = {
		type = triggerTypes.CountdownFinished,
		parameters = {
			countdownID = 'raidersCountdown',
		},
		actions = { 'disbandRaiders' },
	},

	enemySquadDisbanded = {
		type = triggerTypes.SquadDisbanded,
		parameters = {
			teamName = 'enemy',
		},
		actions = { 'messageSquadDisbanded' },
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

	defineReserves = {
		type = actionTypes.DefineSquad,
		parameters = {
			squadName = 'reserves',
			teamName = 'enemy',
			position = { x = 5000, z = 1500 },
			gatherRange = 700,
			composition = { corthud = 4 },
		},
	},

	messageDefineSquads = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Squads test: the enemy bot lab builds three grunts, which gather east of it.",
		},
	},

	cancelReserves = {
		type = actionTypes.CancelSquad,
		parameters = {
			squadName = 'reserves',
		},
	},

	messageCancelReserves = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Squads test: the reserves are cancelled, so the lab builds no thugs.",
		},
	},

	messageRaidersAssembled = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Squads test: the raiders have assembled, and go to defend the west end of the plateau.",
		},
	},

	runRaiders = {
		type = actionTypes.RunSquad,
		parameters = {
			squadName = 'raiders',
			task = 'DEFEND',
			position = { x = 4150, z = 1500 },
		},
	},

	startRaidersCountdown = {
		type = actionTypes.AddCountdown,
		parameters = {
			countdownID = 'raidersCountdown',
			seconds = 30,
		},
	},

	disbandRaiders = {
		type = actionTypes.DisbandSquad,
		parameters = {
			squadName = 'raiders',
		},
	},

	messageSquadDisbanded = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Squads test: a squad of the enemy has disbanded.",
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
