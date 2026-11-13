---
--- Campaign AI regions test mission.
---
--- Needs the campaign AI on the enemy team: tools/StartScripts/startscript_mission_api_campaign_ai_quicksilver.txt
--- with missionoptions set to the base64url of {"entryPoint":"singleplayer/mission-api-tests/ai_regions_test.lua"}:
--- eyJlbnRyeVBvaW50Ijoic2luZ2xlcGxheWVyL21pc3Npb24tYXBpLXRlc3RzL2FpX3JlZ2lvbnNfdGVzdC5sdWEifQ==
---
--- Expected timeline, watching the enemy team:
---   5 s   the west end of the enemy plateau becomes a region, and the lab starts on three grunts
---   later the grunts stand together east of the lab, then walk west past it
---         a message says the raiders entered the west end, and they turn back east
---         a message says the raiders left the west end, and the region is cleared
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	start = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 5,
		},
		actions = { 'defineWestEnd', 'defineRaiders' },
	},

	raidersAssembled = {
		type = triggerTypes.SquadAssembled,
		parameters = {
			squadName = 'raiders',
		},
		actions = { 'sendRaidersWest' },
	},

	raidersEnteredWestEnd = {
		type = triggerTypes.SquadEnteredRegion,
		parameters = {
			regionName = 'westEnd',
			squadName = 'raiders',
		},
		actions = { 'messageEntered', 'sendRaidersEast' },
	},

	raidersLeftWestEnd = {
		type = triggerTypes.SquadLeftRegion,
		parameters = {
			regionName = 'westEnd',
		},
		actions = { 'messageLeft', 'clearWestEnd' },
	},
}

local actions = {

	defineWestEnd = {
		type = actionTypes.DefineAiRegion,
		parameters = {
			regionName = 'westEnd',
			teamName = 'enemy',
			area = { x1 = 4100, z1 = 1300, x2 = 4500, z2 = 1800 },
		},
	},

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

	sendRaidersWest = {
		type = actionTypes.RunSquad,
		parameters = {
			squadName = 'raiders',
			task = 'DEFEND',
			position = { x = 4150, z = 1500 },
		},
	},

	messageEntered = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "AI regions test: the raiders entered the west end, and turn back.",
		},
	},

	sendRaidersEast = {
		type = actionTypes.RunSquad,
		parameters = {
			squadName = 'raiders',
			task = 'DEFEND',
			position = { x = 5050, z = 1500 },
		},
	},

	messageLeft = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "AI regions test: the raiders left the west end.",
		},
	},

	clearWestEnd = {
		type = actionTypes.ClearAiRegion,
		parameters = {
			regionName = 'westEnd',
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
