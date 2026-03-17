local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local triggers = {

	spawnCon = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 60,
		},
		actions = { 'spawnCon' },
	},
}

local actions = {
	spawnCon = {
		type = actionTypes.SpawnUnits,
		parameters = {
            unitDefName = 'corck',
			teamID = 0,
			position = { x = 1800, z = 1800 },
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
