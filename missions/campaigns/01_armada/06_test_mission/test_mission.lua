local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	spawnCons1 = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
			maxRepeats = 3,
		},
		parameters = {
			seconds = 0,
			interval = 9,
		},
		actions = { 'spawnCons1' },
	},

	spawnEnergyGrid1 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 40,
		},
		actions = { 'spawnEnergyGrid1', 'nameEnergyGrid1' },
	},

	killCons = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 7,
		},
		actions = { 'killCons1', 'messageConsKilled' },
	},

	selfDestructCons = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 16,
		},
		actions = { 'selfDestructCons1', 'messageSelfDestructCons1' },
	},

	reclaimCons = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 25,
		},
		actions = { 'despawnCons1', 'messageConsReclaimed' },
	},

	transferCons1 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 30,
		},
		actions = { 'transferCons1', 'messageTransferCons1' },
	},

	transferCons2 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 37,
		},
		actions = { 'transferCons2', 'messageTransferCons2' },
	},

	despawnEnergyGrid1 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 43,
		},
		actions = { 'despawnEnergyGrid1', 'messageEnergyGrid1Reclaimed' },
	},

	doNotKillCons = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 47,
		},
		actions = { 'unnameCons', 'killCons1', 'messageConsNotKilled' },
	},

	explosionOnFusions = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 50,
		},
		actions = { 'spawnExplosion' },
	},

	gameEnd = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 57,
		},
		actions = { 'gameEnd' },
	},
}

local actions = {
	spawnCons1 = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'corck', x = 1800, z = 1600, facing = 'n', teamName = 'thePlayerTeam', unitName = 'con-bots', quantity = 9, spacing = 32 },
			},
		},
	},

	spawnEnergyGrid1 = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armfus', x = 1900, z = 2200, facing = 'e', teamName = 'thePlayerTeam', quantity = 18 },
			},
		},
	},

	nameEnergyGrid1 = {
		type = actionTypes.NameUnits,
		parameters = {
			unitName = 'fusions',
			teamName = 'thePlayerTeam',
			unitDefName = 'armfus',
			area = { x1 = 0, z1 = 0, x2 = 999999, z2 = 2200 },
		},
	},

	killCons1 = {
		type = actionTypes.DestroyUnits,
		parameters = {
			unitName = 'con-bots',
		},
	},

	messageConsKilled = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "Let's kill those bots.",
		},
	},

	selfDestructCons1 = {
		type = actionTypes.SelfDestructUnits,
		parameters = {
			unitName = 'con-bots',
		},
	},

	messageSelfDestructCons1 = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "They blow themselves up!",
		},
	},

	despawnCons1 = {
		type = actionTypes.ReclaimUnits,
		parameters = {
			unitName = 'con-bots',
		},
	},

	messageConsReclaimed = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "These just vanish...",
		},
	},

	despawnEnergyGrid1 = {
		type = actionTypes.ReclaimUnits,
		parameters = {
			unitName = 'fusions',
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
			newTeamName = 'theEnemyTeam',
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
			newTeamName = 'thePlayerTeam',
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
			allyTeamNames = { 'thePlayerAllyTeam' },
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
