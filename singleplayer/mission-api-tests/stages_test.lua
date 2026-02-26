local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local initialStage = 'firstStage'
local stages = {

	firstStage = {
		title = "The First Stage",
	},

	secondStage = {
		title = "The Second Stage",
	},
}

local triggers = {

	messageFirstStage = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
			stages = { 'firstStage' },
		},
		parameters = {
			gameFrame = 1,
			interval = 60,
		},
		actions = { 'messageFirstStage' },
	},

	messageSecondStage = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
			stages = { 'secondStage' },
		},
		parameters = {
			gameFrame = 1,
			interval = 60,
		},
		actions = { 'messageSecondStage' },
	},

	changeStage = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = false,
		},
		parameters = {
			gameFrame = 180,
		},
		actions = { 'changeToSecondStage' },
	},
}

local actions = {

	messageFirstStage = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "This is the FIRST stage",
		},
	},

	messageSecondStage = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "This is the SECOND stage",
		},
	},

	changeToSecondStage = {
		type = actionTypes.ChangeStage,
		parameters = {
			stageID = 'secondStage',
		},
	},
}

return {
	InitialStage = initialStage,
	Stages = stages,
	Triggers = triggers,
	Actions = actions,
}
