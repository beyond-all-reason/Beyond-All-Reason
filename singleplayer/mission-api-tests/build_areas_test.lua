---
--- Campaign AI build areas test mission.
---
--- Needs the campaign AI on the enemy team: tools/StartScripts/startscript_mission_api_campaign_ai_quicksilver.txt
--- with missionoptions set to the base64url of {"entryPoint":"singleplayer/mission-api-tests/build_areas_test.lua"}:
--- eyJlbnRyeVBvaW50Ijoic2luZ2xlcGxheWVyL21pc3Npb24tYXBpLXRlc3RzL2J1aWxkX2FyZWFzX3Rlc3QubHVhIn0=
---
--- Expected timeline, watching the enemy team:
---   5 s   the enemy is told to fill the middle of its plateau with dragon's teeth
---   later, once its commander has a moment, eight teeth stand in two rows of four, built two at a time
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	defineTeeth = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 5,
		},
		actions = { 'defineTeeth', 'messageDefineTeeth' },
	},
}

local actions = {

	defineTeeth = {
		type = actionTypes.DefineBuildArea,
		parameters = {
			buildAreaName = 'teeth',
			teamName = 'enemy',
			area = { x1 = 4350, z1 = 1380, x2 = 4550, z2 = 1480 },
			unitDefName = 'cordrag',
			buildsAtOnce = 2,
		},
	},

	messageDefineTeeth = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Build areas test: the enemy fills the middle of its plateau with dragon's teeth.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
