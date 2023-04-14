local triggerTypes = GG['MissionAPI'].TriggersController.Types
local actionTypes = GG['MissionAPI'].ActionsController.Types

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