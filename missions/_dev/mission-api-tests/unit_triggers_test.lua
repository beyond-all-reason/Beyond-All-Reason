local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local triggers = {

	spawnTurretAndBots = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 30,
		},
		actions = { 'spawnTurret', 'spawnBots', 'moveBots1' },
	},

	botDwells = {
		type = triggerTypes.UnitDwellLocation,
		settings = {
			repeating = true,
			maxRepeats = 77,
		},
		parameters = {
			nameRequired = 'bots',
			teamID = 0,
			unitDefName = 'armpw',
			duration = 60,
			area = { x1 = 2000, z1 = 2300, x2 = 2200, z2 = 2500 },
		},
		actions = { 'messageBotDwells' },
	},

	botDwellsAfterRes = {
		type = triggerTypes.UnitDwellLocation,
		settings = {
			repeating = true,
			maxRepeats = 77,
			prerequisites = { 'unitRessed' },
		},
		parameters = {
			nameRequired = 'bots',
			teamID = 0,
			unitDefName = 'armpw',
			duration = 60,
			area = { x1 = 2000, z1 = 2300, x2 = 2200, z2 = 2500 },
		},
		actions = { 'messageBotDwellsAfterRes' },
	},

	botExists = {
		type = triggerTypes.UnitExists,
		parameters = {
			unitDefName = 'armpw',
		},
		actions = { 'messageBotExists' },
	},

	botNotExists = {
		type = triggerTypes.UnitNotExists,
		parameters = {
			unitName = 'bots',
		},
		actions = { 'messageBotNotExists' },
	},

	botDied = {
		type = triggerTypes.UnitKilled,
		parameters = {
			unitName = 'bots',
		},
		actions = { 'messageBotDied' },
	},

	botEnteredLocation = {
		type = triggerTypes.UnitEnteredLocation,
		parameters = {
			nameRequired = 'bots',
			teamID = 0,
			unitDefName = 'armpw',
			area = { x1 = 1700, z1 = 2300, x2 = 1900, z2 = 2600 },
		},
		actions = { 'messageBotEnteredLocation', 'spawnCapturable', 'spawnDecoy' },
	},

	botLeftLocation = {
		type = triggerTypes.UnitLeftLocation,
		parameters = {
			nameRequired = 'bots',
			teamID = 0,
			unitDefName = 'armpw',
			area = { x1 = 1700, z1 = 2300, x2 = 1900, z2 = 2600 },
		},
		-- for some reason, CMD.CAPTURE doesn't work in the same frame as either acting unit or its target is spawned
		actions = { 'messageBotLeftLocation', 'orderDecoysCaptureAndBuild', 'spawnEngineer', 'orderEngineerMove' },
	},

	unitCaptured = {
		type = triggerTypes.UnitCaptured,
		parameters = {
			unitDefName = 'armwin',
		},
		actions = { 'messageCaptured', 'spawnResBots', 'orderRes' },
	},

	constructionStartedSolar = {
		type = triggerTypes.ConstructionStarted,
		parameters = {
			unitDefName = 'armsolar',
			teamID = 0,
		},
		actions = { 'messageConstructionStartedSolar' },
	},

	constructionFinishedSolar = {
		type = triggerTypes.ConstructionFinished,
		parameters = {
			unitDefName = 'armsolar',
			teamID = 0,
		},
		actions = { 'messageConstructionFinishedSolar' },
	},

	unitRessed = {
		type = triggerTypes.UnitResurrected,
		parameters = {
			unitDefName = 'armllt',
			teamID = 0,
		},
		actions = { 'messageRessed' },
	},

	engineerSpotted = {
		type = triggerTypes.UnitSpotted,
		parameters = {
			unitName = 'engineers',
			unitDefName = 'corfast',
			owningTeamID = 1,
		},
		actions = { 'messageEngineerSpotted' },
	},

	engineerUnspotted = {
		type = triggerTypes.UnitUnspotted,
		parameters = {
			unitName = 'engineers',
			unitDefName = 'corfast',
			owningTeamID = 1,
			spottingAllyTeamID = 0,
		},
		actions = { 'messageEngineerUnspotted' },
	},
}

local actions = {

	spawnTurret = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'bots',
            unitDefName = 'armllt',
			teamID = 1,
			position = { x = 1800, z = 2200 },
		},
	},

	spawnBots = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'bots',
            unitDefName = 'armpw',
			teamID = 0,
			quantity = 4,
			position = { x = 1800, z = 1600 },
		},
	},

	moveBots1 = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'bots',
			orders = {
				{ CMD.FIGHT, { 1800, 0, 2400 } },
				{ CMD.FIGHT, { 2100, 0, 2400 }, { 'shift' } },
			},
		},
	},

	messageBotDwells = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Bot is dwelling!",
		},
	},

	messageBotDwellsAfterRes = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Bot is dwelling AFTER turret was res'd!",
		},
	},

	messageBotExists = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Bot now exists!",
		},
	},

	messageBotDied = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Bot has been destroyed!",
		},
	},

	messageBotNotExists = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Bot ceased to exist!",
		},
	},

	messageBotEnteredLocation = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Bot entered location!",
		},
	},

	messageBotLeftLocation = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Bot left location!",
		},
	},

	spawnDecoy = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'decoys',
			unitDefName = 'armdecom',
			teamID = 0,
			position = { x = 1900, z = 2600 },
		},
	},

	spawnCapturable = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitDefName = 'armwin',
			teamID = 1,
			position = { x = 1600, z = 2800 },
		},
	},

	orderDecoysCaptureAndBuild = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'decoys',
			orders = {
				{ CMD.FIRE_STATE, CMD.FIRESTATE_HOLDFIRE },
				{ CMD.CAPTURE, { 1600, 0, 2800, 200 } },
				{ 'armsolar', { 1700, 0, 2600, 3 }, { 'shift' } },
			},
		},
	},

	messageCaptured = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Unit captured!",
		},
	},

	messageConstructionStartedSolar = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Construction of solar started!",
		},
	},

	messageConstructionFinishedSolar = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Construction of solar finished!",
		},
	},

	spawnResBots = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'res',
			unitDefName = 'armrectr',
			teamID = 0,
			quantity = 4,
			position = { x = 1900, z = 2600 },
		},
	},

	orderRes = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'res',
			orders = {
				{ CMD.RESURRECT, { 1800, 0, 2200, 200 } },
			},
		},
	},

	messageRessed = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Turret resurrected!",
		},
	},

	spawnEngineer = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'engineers',
			unitDefName = 'corfast',
			teamID = 1,
			position = { x = 1500, z = 3400 },
		},
	},

	orderEngineerMove = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'engineers',
			orders = {
				{ CMD.MOVE, { 1600, 0, 2900 }, { 'shift' } },
				{ CMD.MOVE, { 2000, 0, 3400 }, { 'shift' } },
			},
		},
	},

	messageEngineerSpotted = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Engineer spotted!",
		},
	},

	messageEngineerUnspotted = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Engineer unspotted!",
		},
	},
}

return {
	LobbyData = lobbyData,
	StartScript = startScript,
	Triggers = triggers,
	Actions = actions,
}
