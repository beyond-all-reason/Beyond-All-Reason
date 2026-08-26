local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	spawnTurretAndBots = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 1,
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
			unitName = 'bots',
			teamName = 'thePlayerTeam',
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
			unitName = 'bots',
			teamName = 'thePlayerTeam',
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
			unitName = 'bots',
			teamName = 'thePlayerTeam',
			unitDefName = 'armpw',
			area = { x1 = 1700, z1 = 2300, x2 = 1900, z2 = 2600 },
		},
		actions = { 'messageBotEnteredLocation', 'spawnCapturable', 'spawnDecoy' },
	},

	botLeftLocation = {
		type = triggerTypes.UnitLeftLocation,
		parameters = {
			unitName = 'bots',
			teamName = 'thePlayerTeam',
			unitDefName = 'armpw',
			area = { x1 = 1700, z1 = 2300, x2 = 1900, z2 = 2600 },
		},
		-- for some reason, CMD.CAPTURE doesn't work in the same frame as either acting unit or its target is spawned
		actions = { 'messageBotLeftLocation', 'orderDecoysCaptureAndBuild' },
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
			teamName = 'thePlayerTeam',
		},
		actions = { 'messageConstructionStartedSolar' },
	},

	constructionHalfwaySolar = {
		type = triggerTypes.ConstructionProgress,
		parameters = {
			unitDefName = 'armsolar',
			teamName = 'thePlayerTeam',
			progress = 0.5,
		},
		actions = { 'messageConstructionHalfwaySolar' },
	},

	constructionFinishedSolar = {
		type = triggerTypes.ConstructionFinished,
		parameters = {
			unitDefName = 'armsolar',
			teamName = 'thePlayerTeam',
		},
		actions = { 'messageConstructionFinishedSolar' },
	},

	constructionStartedByDecoy = {
		type = triggerTypes.ConstructionStarted,
		parameters = {
			unitDefName = 'armsolar',
			teamName = 'thePlayerTeam',
			builderName = 'decoys',
		},
		actions = { 'messageConstructionStartedByDecoy' },
	},

	-- We don't actually get any finishee attribution.
	constructionFinishedByDecoy = {
		type = triggerTypes.ConstructionFinished,
		parameters = {
			unitDefName = 'armsolar',
			teamName = 'thePlayerTeam',
		},
		actions = { 'messageConstructionFinishedByDecoy' },
	},

	spawnCancelDemo = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 10, -- The build is underway before the reclaim.
		},
		actions = { 'spawnCanceler', 'orderCancelerBuild' },
	},

	reclaimCancelDemo = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 21, -- Reclaim mid-build: ~11s into a ~32s solar.
		},
		actions = { 'nameDoomedSolar', 'reclaimDoomedSolar' },
	},

	constructionCanceledSolar = {
		type = triggerTypes.ConstructionCanceled,
		parameters = {
			unitDefName = 'armsolar',
			teamName = 'thePlayerTeam',
		},
		actions = { 'messageConstructionCanceledSolar' },
	},

	spawnAssistDemo = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 30,
		},
		actions = { 'spawnPlacer', 'orderPlacerBuild' },
	},

	joinAssistDemo = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 36, -- The build is in progress, so an identical build-order becomes a build-assist.
		},
		actions = { 'spawnAssister', 'orderAssisterBuild' },
	},

	constructionStartedByAssister = {
		type = triggerTypes.ConstructionStarted,
		parameters = {
			unitDefName = 'armsolar',
			teamName = 'thePlayerTeam',
			builderName = 'assister',
		},
		actions = { 'messageConstructionStartedByAssister' },
	},

	unitRessed = {
		type = triggerTypes.UnitResurrected,
		parameters = {
			unitDefName = 'armllt',
			teamName = 'thePlayerTeam',
		},
		actions = { 'messageRessed' },
	},

	engineerDetected = {
		type = triggerTypes.UnitDetected,
		parameters = {
			unitName = 'engineers',
			unitDefName = 'corfast',
			owningTeamName = 'theEnemyTeam',
			sensorTypes = { 'vision' },
		},
		actions = { 'messageEngineerDetected' },
	},

	engineerUndetected = {
		type = triggerTypes.UnitUndetected,
		parameters = {
			unitName = 'engineers',
			unitDefName = 'corfast',
			owningTeamName = 'theEnemyTeam',
			sensorAllyTeamName = 'thePlayerAllyTeam',
			sensorTypes = { 'vision' },
		},
		actions = { 'messageEngineerUndetected' },
	},

	engineerDetectedByRadar = {
		type = triggerTypes.UnitDetected,
		parameters = {
			unitName = 'engineers',
			unitDefName = 'corfast',
			owningTeamName = 'theEnemyTeam',
			sensorAllyTeamName = 'thePlayerAllyTeam',
			sensorTypes = { 'radar' },
		},
		actions = { 'messageEngineerDetectedByRadar' },
	},

	engineerUndetectedByRadar = {
		type = triggerTypes.UnitUndetected,
		parameters = {
			unitName = 'engineers',
			unitDefName = 'corfast',
			owningTeamName = 'theEnemyTeam',
			sensorAllyTeamName = 'thePlayerAllyTeam',
			sensorTypes = { 'radar' },
		},
		actions = { 'messageEngineerUndetectedByRadar' },
	},

	engineerDetectedBySeismic = {
		type = triggerTypes.UnitDetected,
		settings = {
			repeating = true,
		},
		parameters = {
			unitName = 'engineers',
			unitDefName = 'corfast',
			owningTeamName = 'theEnemyTeam',
			sensorAllyTeamName = 'thePlayerAllyTeam',
			sensorTypes = { 'seismic' },
		},
		actions = { 'messageEngineerDetectedBySeismic' },
	},

	engineerUndetectedBySeismic = {
		type = triggerTypes.UnitUndetected,
		parameters = {
			unitName = 'engineers',
			unitDefName = 'corfast',
			owningTeamName = 'theEnemyTeam',
			sensorAllyTeamName = 'thePlayerAllyTeam',
			sensorTypes = { 'seismic' },
		},
		actions = { 'messageEngineerUndetectedBySeismic' },
	},
}

local actions = {

	spawnTurret = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armllt', x = 1800, z = 2200, teamName = 'theEnemyTeam' },
			},
		},
	},

	spawnBots = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armpw', x = 1800, z = 1600, teamName = 'thePlayerTeam', unitName = 'bots', quantity = 6 },
			},
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
			unitLoadout = {
				{ unitDefName = 'armdecom', x = 1900, z = 2600, teamName = 'thePlayerTeam', unitName = 'decoys' },
			},
		},
	},

	spawnCapturable = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armwin', x = 1600, z = 2800, teamName = 'theEnemyTeam' },
			},
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

	messageConstructionHalfwaySolar = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Construction of solar halfway done!",
		},
	},

	messageConstructionFinishedSolar = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Construction of solar finished!",
		},
	},

	messageConstructionStartedByDecoy = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Solar construction started by the decoy commander!",
		},
	},

	messageConstructionFinishedByDecoy = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Some unit, maybe even the decoy commander, finished a solar!",
		},
	},

	messageConstructionCanceledSolar = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "The canceler's solar was reclaimed mid-build (canceled)!",
		},
	},

	messageConstructionStartedByAssister = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "The assister joined the placer's solar as a build-assist!",
		},
	},

	spawnCanceler = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armck', x = 2400, z = 2400, teamName = 'thePlayerTeam', unitName = 'canceler' },
			},
		},
	},

	orderCancelerBuild = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'canceler',
			orders = {
				{ 'armsolar', { 2400, 0, 2480 } },
			},
		},
	},

	nameDoomedSolar = {
		type = actionTypes.NameUnits,
		parameters = {
			unitName = 'doomedSolar',
			teamName = 'thePlayerTeam',
			unitDefName = 'armsolar',
			area = { x = 2400, z = 2480, radius = 100 },
		},
	},

	reclaimDoomedSolar = {
		type = actionTypes.ReclaimUnits,
		parameters = {
			unitName = 'doomedSolar',
		},
	},

	spawnPlacer = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armck', x = 2520, z = 2480, teamName = 'thePlayerTeam', unitName = 'placer' },
			},
		},
	},

	orderPlacerBuild = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'placer',
			orders = {
				{ 'armsolar', { 2600, 0, 2480 } },
			},
		},
	},

	-- The same order at the same place, so the placer's build frame takes it as a build-assist:
	spawnAssister = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armck', x = 2680, z = 2480, teamName = 'thePlayerTeam', unitName = 'assister' },
			},
		},
	},

	orderAssisterBuild = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'assister',
			orders = {
				{ 'armsolar', { 2600, 0, 2480 } },
			},
		},
	},

	spawnResBots = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armrectr', x = 1900, z = 2600, teamName = 'thePlayerTeam', unitName = 'res', quantity = 4 },
			},
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
			unitLoadout = {
				{ unitDefName = 'corfast', x = 1500, z = 3400, teamName = 'theEnemyTeam', unitName = 'engineers' },
			},
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

	messageEngineerDetected = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Engineer detected!",
		},
	},

	messageEngineerUndetected = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Engineer undetected!",
		},
	},

	messageEngineerDetectedByRadar = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Engineer detected by radar!",
		},
	},

	messageEngineerUndetectedByRadar = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Engineer undetected by radar!",
		},
	},

	messageEngineerDetectedBySeismic = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Engineer detected by seismic!",
		},
	},

	messageEngineerUndetectedBySeismic = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Engineer undetected by seismic!",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
