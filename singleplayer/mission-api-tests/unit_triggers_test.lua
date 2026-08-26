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
			unitName = 'bots',
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
			unitName = 'bots',
			teamID = 0,
			unitDefName = 'armpw',
			area = { x1 = 1700, z1 = 2300, x2 = 1900, z2 = 2600 },
		},
		actions = { 'messageBotEnteredLocation', 'spawnCapturable', 'spawnDecoy' },
	},

	botLeftLocation = {
		type = triggerTypes.UnitLeftLocation,
		parameters = {
			unitName = 'bots',
			teamID = 0,
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
			teamID = 0,
		},
		actions = { 'messageConstructionStartedSolar' },
	},

	constructionHalfwaySolar = {
		type = triggerTypes.ConstructionProgress,
		parameters = {
			unitDefName = 'armsolar',
			teamID = 0,
			progress = 0.5,
		},
		actions = { 'messageConstructionHalfwaySolar' },
	},

	constructionFinishedSolar = {
		type = triggerTypes.ConstructionFinished,
		parameters = {
			unitDefName = 'armsolar',
			teamID = 0,
		},
		actions = { 'messageConstructionFinishedSolar' },
	},

	constructionStartedByDecoy = {
		type = triggerTypes.ConstructionStarted,
		parameters = {
			unitDefName = 'armsolar',
			teamID = 0,
			builderName = 'decoys',
		},
		actions = { 'messageConstructionStartedByDecoy' },
	},

	-- We don't actually get any finishee attribution.
	constructionFinishedByDecoy = {
		type = triggerTypes.ConstructionFinished,
		parameters = {
			unitDefName = 'armsolar',
			teamID = 0,
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
			teamID = 0,
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
			teamID = 0,
			builderName = 'assister',
		},
		actions = { 'messageConstructionStartedByAssister' },
	},

	spawnReclaimDemo = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 50,
		},
		actions = { 'spawnDoomedRadar', 'spawnReclaimer' },
	},

	-- Split off the spawn, since an order does not take on the frame its target unit is spawned.
	orderReclaimDemo = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 52,
		},
		actions = { 'orderReclaimerReclaim' },
	},

	unitReclaimedRadar = {
		type = triggerTypes.UnitReclaimed,
		parameters = {
			unitDefName = 'armrad',
			teamID = 0,
		},
		actions = { 'messageUnitReclaimedRadar' },
	},

	unitReclaimedByName = {
		type = triggerTypes.UnitReclaimed,
		parameters = {
			unitName = 'doomedRadar',
		},
		actions = { 'messageUnitReclaimedByName' },
  },
	spawnProductionDemo = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 45,
		},
		actions = { 'spawnFactories', 'orderBotLabBuilds', 'orderVehiclePlantBuilds' },
	},

	-- Fires once per buildee, so twice over the bot lab's two pawns.
	productionStartedPawn = {
		type = triggerTypes.ProductionStarted,
		settings = {
			repeating = true,
		},
		parameters = {
			unitDefName = 'armpw',
			teamID = 0,
		},
		actions = { 'messageProductionStartedPawn' },
	},

	productionStartedByBotLab = {
		type = triggerTypes.ProductionStarted,
		parameters = {
			unitDefName = 'armck',
			teamID = 0,
			factoryName = 'botlab',
		},
		actions = { 'messageProductionStartedByBotLab' },
	},

	productionStartedByVehiclePlant = {
		type = triggerTypes.ProductionStarted,
		parameters = {
			unitDefName = 'armfav',
			teamID = 0,
			factoryDefName = 'armvp',
		},
		actions = { 'messageProductionStartedByVehiclePlant' },
	},

	unitRessed = {
		type = triggerTypes.UnitResurrected,
		parameters = {
			unitDefName = 'armllt',
			teamID = 0,
		},
		actions = { 'messageRessed' },
	},

}

local actions = {

	spawnTurret = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armllt', x = 1800, z = 2200, team = 1, unitName = 'bots' },
			},
		},
	},

	spawnBots = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armpw', x = 1800, z = 1600, team = 0, unitName = 'bots', quantity = 4 },
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
				{ unitDefName = 'armdecom', x = 1900, z = 2600, team = 0, unitName = 'decoys' },
			},
		},
	},

	spawnCapturable = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armwin', x = 1600, z = 2800, team = 1 },
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
				{ unitDefName = 'armck', x = 2400, z = 2400, team = 0, unitName = 'canceler' },
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
			teamID = 0,
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
				{ unitDefName = 'armck', x = 2520, z = 2480, team = 0, unitName = 'placer' },
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
				{ unitDefName = 'armck', x = 2680, z = 2480, team = 0, unitName = 'assister' },
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

	messageUnitReclaimedRadar = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "A radar was reclaimed by a builder!",
		},
	},

	messageUnitReclaimedByName = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "The doomed radar, by name, was reclaimed!",
		},
	},

	spawnDoomedRadar = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armrad', x = 2400, z = 3000, team = 0, unitName = 'doomedRadar' },
			},
		},
	},

	spawnReclaimer = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armck', x = 2560, z = 3000, team = 0, unitName = 'reclaimer' },
			},
		},
	},

	-- An ordered reclaim, not the ReclaimUnits action: that one destroys by Lua and is not a reclaim.
	orderReclaimerReclaim = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'reclaimer',
			orders = {
				{ CMD.RECLAIM, { unitName = 'doomedRadar' } },
			}
		},
	},

	messageProductionStartedPawn = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "A pawn went onto a build pad (production started)!",
		},
	},

	messageProductionStartedByBotLab = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "The named bot lab started a construction bot!",
		},
	},

	messageProductionStartedByVehiclePlant = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "A vehicle plant, whichever one, started a fast assault vehicle!",
		},
	},

	spawnFactories = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armlab', x = 2400, z = 3000, team = 0, unitName = 'botlab' },
				{ unitDefName = 'armvp', x = 2750, z = 3000, team = 0, unitName = 'vehicleplant' },
			},
		},
	},

	-- Factory build orders carry no position, so their parameters are empty.
	orderBotLabBuilds = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'botlab',
			orders = {
				{ 'armpw', {} },
				{ 'armck', {}, { 'shift' } },
				{ 'armpw', {}, { 'shift' } },
			},
		},
	},

	orderVehiclePlantBuilds = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'vehicleplant',
			orders = {
				{ 'armfav', {} },
			},
		},
	},

	spawnResBots = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armrectr', x = 1900, z = 2600, team = 0, unitName = 'res', quantity = 4 },
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

}

return {
	Triggers = triggers,
	Actions = actions,
}
