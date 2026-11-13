---
--- Campaign AI base plan test mission.
---
--- Needs the campaign AI on the enemy team: tools/StartScripts/startscript_mission_api_campaign_ai_quicksilver.txt
--- with missionoptions set to the base64url of {"entryPoint":"singleplayer/mission-api-tests/base_plan_test.lua"}:
--- eyJlbnRyeVBvaW50Ijoic2luZ2xlcGxheWVyL21pc3Npb24tYXBpLXRlc3RzL2Jhc2VfcGxhbl90ZXN0Lmx1YSJ9
---
--- Expected timeline, watching the enemy team:
---   5 s    the enemy gets a build order for the west of its plateau: a laser tower, a radar tower,
---          a second laser tower, then a row of six dragon's teeth along the north edge
---   later  the structures stand within a minute, each on the build grid next to its position
---          destroy the first laser tower and the enemy builds it again; the second it does not
---   120 s  the plan is cancelled: from now on the first laser tower is not built again either
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local function structure(unitDefName, x, z, rebuild)
	return {
		type = actionTypes.AddToBasePlan,
		parameters = {
			basePlanName = 'westOutpost',
			teamName = 'enemy',
			unitDefName = unitDefName,
			position = { x = x, z = z },
			rebuild = rebuild,
		},
	}
end

local triggers = {

	planOutpost = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 5,
		},
		actions = {
			'laserTower1', 'radarTower', 'laserTower2',
			'tooth1', 'tooth2', 'tooth3', 'tooth4', 'tooth5', 'tooth6',
			'messagePlanOutpost',
		},
	},

	cancelOutpost = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 120,
		},
		actions = { 'cancelOutpost', 'messageCancelOutpost' },
	},
}

local actions = {

	laserTower1 = structure('corllt', 4300, 1400, true),
	radarTower = structure('corrad', 4350, 1550),
	laserTower2 = structure('corllt', 4500, 1380),
	tooth1 = structure('cordrag', 4250, 1310),
	tooth2 = structure('cordrag', 4300, 1310),
	tooth3 = structure('cordrag', 4350, 1310),
	tooth4 = structure('cordrag', 4400, 1310),
	tooth5 = structure('cordrag', 4450, 1310),
	tooth6 = structure('cordrag', 4500, 1310),

	messagePlanOutpost = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Base plan test: the enemy builds an outpost in the west of its plateau.",
		},
	},

	cancelOutpost = {
		type = actionTypes.CancelBasePlan,
		parameters = {
			basePlanName = 'westOutpost',
		},
	},

	messageCancelOutpost = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = "Base plan test: the outpost's build order is cancelled.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
