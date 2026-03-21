local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local location = { x1 = 1700, z1 = 1900, x2 = 1900, z2 = 2200 }

local triggers = {

	spawnBots = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 30,
		},
		actions = { 'spawnBots', 'moveBots' },
	},

	botEnteredLocation = {
		type = triggerTypes.UnitEnteredLocation,
		settings = {
			repeating = true,
		},
		parameters = {
			nameRequired = 'bots',
			teamID = 0,
			unitDefName = 'armpw',
			area = location,
		},
		actions = { 'messageBotEnteredLocation', 'spawnDecoy' },
	},

	botLeftLocation = {
		type = triggerTypes.UnitLeftLocation,
		settings = {
			repeating = true,
		},
		parameters = {
			nameRequired = 'bots',
			teamID = 0,
			unitDefName = 'armpw',
			area = location,
		},
		actions = { 'messageBotLeftLocation', 'spawnDecoy' },
	},
}

local actions = {

	spawnBots = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'bots',
            unitDefName = 'armpw',
			teamID = 0,
			quantity = 2,
			position = { x = 1800, z = 1600 },
			spacing = 48,
		},
	},

	moveBots = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'bots',
			orders = {
				{ CMD.MOVE, { 1800, 0, 2500 } },
			},
		},
	},

	messageBotEnteredLocation = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "A bot entered location, let's spawn a decoy on top of it.",
		},
	},

	messageBotLeftLocation = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "A bot left location, let's spawn a decoy on top of it.",
		},
	},

	spawnDecoy = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitDefName = 'armdecom',
			teamID = 0,
			-- position = { x = 1900, z = 2600 },
		},
		provided = {
			positionEntered = 'position',
			positionLeft = 'position',
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
