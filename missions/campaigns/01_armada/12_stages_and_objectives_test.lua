
local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local lobbyData = {
	missionId = "stages_and_objectives_test",
	title = "Stages and Objectives Test",
	description = "Tests stages and objectives.",
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

local initialStage = 'firstStage'
local stages = {
	firstStage = {
		objectives = { 'wait3secs' }
	},
	secondStage = {
		objectives = { 'buildBots' }
	},
	thirdStage = {
		objectives = { 'buildBots', 'destroyBots' }
	}
}

local objectives = {

	wait3secs = {
		textKey = "wait_3_seconds",
		trigger = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				gameFrame = 90,
			},
		},
		nextStage = 'secondStage',
	},

	buildBots = {
		textKey = "build_3_bots",
		amount = 3,
		trigger = {
			type = triggerTypes.ConstructionFinished,
			parameters = {
				unitDefName = 'corak',
				teamName = 'thePlayerTeam',
			},
		},
	},

	destroyBots = {
		textKey = "destroy_all_bots",
		amount = 0,
		trigger = {
			type = triggerTypes.UnitsOwned,
			parameters = {
				unitName = 'bots',
				teamName = 'thePlayerTeam',
			},
		},
	},
}

local triggers = {

	spawnBots = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
			stages = { 'secondStage', 'thirdStage' },
			maxRepeats = 5,
		},
		parameters = {
			gameFrame = 5,
			interval = 60,
		},
		actions = { 'spawnBot' },
	},

	changeStage3 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 210,
		},
		actions = { 'changeToThirdStage', 'spawnBotDestroyer' },
	},
}

local actions = {

	spawnBot = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'corak', x = 1800, z = 1800, teamName = 'thePlayerTeam', unitName = 'bots' },
			},
		},
	},

	changeToThirdStage = {
		type = actionTypes.ChangeStage,
		parameters = {
			stageID = 'thirdStage',
		},
	},

	spawnBotDestroyer = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armllt', x = 1800, z = 2200, teamName = 'theEnemyTeam', quantity = 2 },
			},
		},
	},
}

return {
	LobbyData   = lobbyData,
	StartScript = startScript,
	InitialStage = initialStage,
	Stages = stages,
	Objectives = objectives,
	Triggers = triggers,
	Actions = actions,
}
