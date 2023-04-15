local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local triggers = {
	testTime = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 150,
		},
		actions = { 'helloWorld' },
	},
}

local actions = {
	helloWorld = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Hello World",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}