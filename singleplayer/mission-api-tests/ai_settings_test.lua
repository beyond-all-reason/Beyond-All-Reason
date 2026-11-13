---
--- Campaign AI settings test mission.
---
--- Needs the campaign AI on the enemy team: tools/StartScripts/startscript_mission_api_campaign_ai_quicksilver.txt
--- with missionoptions set to the base64url of {"entryPoint":"singleplayer/mission-api-tests/ai_settings_test.lua"}:
--- eyJlbnRyeVBvaW50Ijoic2luZ2xlcGxheWVyL21pc3Npb24tYXBpLXRlc3RzL2FpX3NldHRpbmdzX3Rlc3QubHVhIn0=
---
--- Expected timeline, watching the enemy team:
---   1 s   the AI may hold none of the map's metal spots: it builds no metal extractors
---         its grunts are told to retreat at 90 % health, and it may send out no scouts
---   75 s  the cap is lifted: the AI builds metal extractors
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	restrict = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 1,
		},
		actions = { 'capMexes', 'gruntsRetreatEarly', 'noScouts', 'messageRestrict' },
	},

	liftCap = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 75,
		},
		actions = { 'liftMexCap', 'messageLiftCap' },
	},
}

local actions = {

	capMexes = {
		type = actionTypes.SetAiMexCap,
		parameters = {
			teamName = 'enemy',
			share = 0,
		},
	},

	gruntsRetreatEarly = {
		type = actionTypes.SetUnitDefRetreatThreshold,
		parameters = {
			unitDefName = 'corak',
			threshold = 0.9,
			teamName = 'enemy',
		},
	},

	noScouts = {
		type = actionTypes.SetAiMilitaryQuota,
		parameters = {
			teamName = 'enemy',
			scouts = 0,
		},
	},

	messageRestrict = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "AI settings test: the enemy may build no metal extractors.",
		},
	},

	liftMexCap = {
		type = actionTypes.SetAiMexCap,
		parameters = {
			teamName = 'enemy',
			share = 1,
		},
	},

	messageLiftCap = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "AI settings test: the enemy may build metal extractors again.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
