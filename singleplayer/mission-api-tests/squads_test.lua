---
--- Campaign AI squads test mission.
---
--- Needs the campaign AI on the enemy team: tools/StartScripts/startscript_mission_api_campaign_ai_quicksilver.txt
--- with missionoptions set to the base64url of {"entryPoint":"singleplayer/mission-api-tests/squads_test.lua"}:
--- eyJlbnRyeVBvaW50Ijoic2luZ2xlcGxheWVyL21pc3Npb24tYXBpLXRlc3RzL3NxdWFkc190ZXN0Lmx1YSJ9
---
--- Expected timeline, watching the enemy team:
---   5 s   the enemy bot lab starts on three grunts for the squad
---   later the three grunts stand together west of the lab
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	defineRaiders = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 5,
		},
		actions = { 'defineRaiders', 'messageDefineRaiders' },
	},
}

local actions = {

	defineRaiders = {
		type = actionTypes.DefineSquad,
		parameters = {
			squadName = 'raiders',
			teamName = 'enemy',
			position = { x = 4400, z = 1500 },
			gatherRange = 700,
			composition = { corak = 3 },
		},
	},

	messageDefineRaiders = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Squads test: the enemy bot lab builds three grunts, which gather west of it.",
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
