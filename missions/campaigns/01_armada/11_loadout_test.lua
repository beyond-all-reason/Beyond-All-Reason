---
--- Test mission demonstrating UnitLoadout and FeatureLoadout.
---

local triggerTypes   = GG['MissionAPI'].TriggerTypes
local actionTypes    = GG['MissionAPI'].ActionTypes

local lobbyData = {
	missionId = "loadout_test",
	title = "Loadout Test",
	description = "Tests pre-spawning units and features via UnitLoadout and FeatureLoadout, and the actions SpawnUnits and CreateFeatures.",
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

	intro = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 1,
		},
		actions = { 'messageIntro' },
	},

	movePlayerCon = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 60,
		},
		actions = { 'movePlayerCon' },
	},

	destroyWreck = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 120,
		},
		actions = { 'destroyWreck', 'messageWreckDestroyed' },
	},

	spawnReinforcements = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 200,
		},
		actions = { 'spawnReinforcements', 'createFeatures', 'messageReinforcementsArrived' },
	},

	actOnReinforcements = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 300,
		},
		actions = { 'moveReinforcements', 'destroyReinforcementWreck', 'messageReinforcementsActedOn' },
	},

	victory = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 600,
		},
		actions = { 'messageEnd', 'victory' },
	},
}

local actions = {

	messageIntro = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'Loadout test: pre-spawned units and features are live. ' ..
			          'Player con has an initial patrol order from loadout. ' ..
			          'The wreck (featureName="the-wreck") will be destroyed.',
		},
	},

	movePlayerCon = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'player-con',
			orders = {
				{ CMD.MOVE, { 2200, 0, 3000 }, {} },
			},
		},
	},

	destroyWreck = {
		type = actionTypes.DestroyFeatures,
		parameters = {
			featureName = 'the-wreck',
		},
	},

	messageWreckDestroyed = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'Wreck destroyed via featureName tracking.',
		},
	},

	spawnReinforcements = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armck',   x = 1900, z = 1700, facing = 'e', teamName = 'thePlayerTeam', unitName = 'reinforcement-con' },
				{ unitDefName = 'armflea', x = 1900, z = 1820, facing = 'e', teamName = 'thePlayerTeam',
				  orders = {
				    { CMD.MOVE, { 2100, 0, 2220 }, {} },
				  },
				},
			},
		},
	},

	createFeatures = {
		type = actionTypes.CreateFeatures,
		parameters = {
			featureLoadout = {
				{ featureDefName = 'corak_dead', x = 1800, z = 1750, facing = 's', featureName = 'reinforcement-wreck' },
			},
		},
	},

	messageReinforcementsArrived = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'Reinforcements spawned via SpawnUnits + CreateFeatures. Con tracked as "reinforcement-con", wreck as "reinforcement-wreck".',
		},
	},

	moveReinforcements = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'reinforcement-con',
			orders = {
				{ CMD.MOVE, { 2200, 0, 3000 }, {} },
			},
		},
	},

	destroyReinforcementWreck = {
		type = actionTypes.DestroyFeatures,
		parameters = {
			featureName = 'reinforcement-wreck',
		},
	},

	messageReinforcementsActedOn = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'Reinforcement con moved and wreck destroyed via names registered by SpawnUnits + CreateFeatures.',
		},
	},

	messageEnd = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'Loadout test complete.',
		},
	},

	victory = {
		type = actionTypes.Victory,
		parameters = {
			allyTeamNames = { 'thePlayerAllyTeam' },
		},
	},
}

local unitLoadout    = {
	-- Player team (team 0).
	{ unitDefName = 'armck', x = 1780, z = 1850, facing = 'e', teamName = 'thePlayerTeam', unitName = 'player-con' },
	{ unitDefName = 'corck', x = 1780, z = 1800, facing = 'e', teamName = 'thePlayerTeam',
	  orders = {
	    { CMD.PATROL, { 1780, 0, 1950 }, {} },
	  },
	},

	-- Enemy team (team 1)
	{ unitDefName = 'corsolar', x = 1700, z = 2150, facing = 'w', teamName = 'theEnemyTeam' },
	{ unitDefName = 'corsolar', x = 1800, z = 2150, facing = 's', teamName = 'theEnemyTeam' },
}

local featureLoadout = {
	{ featureDefName = 'corak_dead',  x = 1900, z = 1800, facing = 's', featureName = 'the-wreck' },
	{ featureDefName = 'armfus_dead', x = 1900, z = 2000, facing = 'e' },
}

return {
	LobbyData   = lobbyData,
	StartScript = startScript,
	Triggers       = triggers,
	Actions        = actions,
	UnitLoadout    = unitLoadout,
	FeatureLoadout = featureLoadout,
}
