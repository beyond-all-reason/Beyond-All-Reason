local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local lobbyData = {
	missionId = "Test Mission",
	title = "Test Mission",
	description = "Tests various actions and triggers, a left over from before tests were added separately for different parts of the API.",
	unlocked = true,
}

local startScript = {
	mapName = "Quicksilver Remake 1.24",
	startPosType = 'chooseBeforeGame',
	allyTeams = {
		thePlayerAllyTeam = {
			teams = {
				thePlayerTeam = {
					name = "TestPlayer",
					Side = 'Cortex',
					StartPosX = 2200,
					StartPosZ = 1500,
				},
			},
		},
		theEnemyAllyTeam = {
			teams = {
				theEnemyTeam = {
					name = "Mission Bots",
					Side = 'Armada',
					StartPosX = 3000,
					StartPosZ = 2400,
					ai = "NullAI",
				},
			}
		},
	},
}

local triggers = {

	spawnCons1 = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
			maxRepeats = 3,
		},
		parameters = {
			gameFrame = 1,
			interval = 280,
		},
		actions = { 'spawnCons1' },
	},

	spawnEnergyGrid1 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 1200,
		},
		actions = { 'spawnEnergyGrid1', 'nameEnergyGrid1' },
	},

	killCons = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 200,
		},
		actions = { 'killCons1', 'messageConsKilled' },
	},

	selfDestructCons = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 480,
		},
		actions = { 'selfDestructCons1', 'messageSelfDestructCons1' },
	},

	reclaimCons = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 760,
		},
		actions = { 'despawnCons1', 'messageConsReclaimed' },
	},

	transferCons1 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 900,
		},
		actions = { 'transferCons1', 'messageTransferCons1' },
	},

	transferCons2 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 1100,
		},
		actions = { 'transferCons2', 'messageTransferCons2' },
	},

	despawnEnergyGrid1 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 1300,
		},
		actions = { 'despawnEnergyGrid1', 'messageEnergyGrid1Reclaimed' },
	},

	doNotKillCons = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 1400,
		},
		actions = { 'unnameCons', 'killCons1', 'messageConsNotKilled' },
	},

	explosionOnFusions = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 1500,
		},
		actions = { 'spawnExplosion' },
	},

	gameEnd = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 1700,
		},
		actions = { 'gameEnd' },
	},
}

local actions = {
	spawnCons1 = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'con-bots',
            unitDefName = 'corck',
			teamID = 0,
			position = { x = 1800, z = 1600 },
			quantity = 9,
			facing = 'n',
			spacing = 32,
		},
	},

	spawnEnergyGrid1 = {
		type = actionTypes.SpawnUnits,
		parameters = {
            unitDefName = 'armfus',
			teamID = 0,
			position = { x = 1900, z = 2200 },
			quantity = 18,
			facing = 'e',
		},
	},

	nameEnergyGrid1 = {
		type = actionTypes.NameUnits,
		parameters = {
			unitName = 'fusions',
			teamID = 0,
			unitDefName = 'armfus',
			area = { x1 = 0, z1 = 0, x2 = 999999, z2 = 2200 },
		},
	},

	killCons1 = {
		type = actionTypes.DespawnUnits,
		parameters = {
			unitName = 'con-bots',
			selfDestruct = false,
			reclaimed = false
		},
	},

	messageConsKilled = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Let's kill those bots.",
		},
	},

	selfDestructCons1 = {
		type = actionTypes.DespawnUnits,
		parameters = {
			unitName = 'con-bots',
			selfDestruct = true,
			reclaimed = false
		},
	},

	messageSelfDestructCons1 = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "They blow themselves up!",
		},
	},

	despawnCons1 = {
		type = actionTypes.DespawnUnits,
		parameters = {
			unitName = 'con-bots',
			selfDestruct = false,
			reclaimed = true
		},
	},

	messageConsReclaimed = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "These just vanish...",
		},
	},

	despawnEnergyGrid1 = {
		type = actionTypes.DespawnUnits,
		parameters = {
			unitName = 'fusions',
			selfDestruct = false,
			reclaimed = true
		},
	},

	messageEnergyGrid1Reclaimed = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Did we pick the right fusions to remove?",
		},
	},

	transferCons1 = {
		type = actionTypes.TransferUnits,
		parameters = {
			unitName = 'con-bots',
			newTeam = 1,
		},
	},

	messageTransferCons1 = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "We give these away.",
		},
	},

	transferCons2 = {
		type = actionTypes.TransferUnits,
		parameters = {
			unitName = 'con-bots',
			newTeam = 0,
		},
	},

	messageTransferCons2 = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "And we take them back.",
		},
	},

	unnameCons = {
		type = actionTypes.UnnameUnits,
		parameters = {
			unitName = 'con-bots',
		},
	},

	messageConsNotKilled = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Let's unname the bots so we don't kill them.",
		},
	},

	spawnExplosion = {
		type = actionTypes.SpawnExplosion,
		parameters = {
			weaponDefName = 'armsilo_nuclear_missile',
			position = { x = 1500, z = 2200 },
		},
	},

	gameEnd = {
		type = actionTypes.Defeat,
		parameters = {
			allyTeamIDs = { 0 },
		},
	},
}

return {
	LobbyData = lobbyData,
	StartScript = startScript,
	Triggers = triggers,
	Actions = actions,
}
