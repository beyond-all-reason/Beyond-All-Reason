---
--- Test mission demonstrating UnitLoadout and FeatureLoadout.
---

local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes  = GG['MissionAPI'].ActionTypes

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
		actions = { 'spawnReinforcements', 'messageReinforcementsArrived' },
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
			message = 'Loadout test: pre-spawned units and features are live. The con (unitName="player-con") will move shortly, then the wreck (featureName="the-wreck") will be destroyed.',
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
		type = actionTypes.DestroyFeature,
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
		type = actionTypes.SpawnLoadout,
		parameters = {
			unitLoadout = {
				{ name = 'armck', x = 1900, z = 1700, facing = 'e', team = 0, unitName = 'reinforcement-con' },
				{ name = 'armflea', x = 1900, z = 1820, facing = 'e', team = 0 },
			},
			featureLoadout = {
				{ name = 'corak_dead', x = 1800, z = 1750, facing = 's', resurrectAs = 'corak', featureName = 'reinforcement-wreck' },
			},
		},
	},

	messageReinforcementsArrived = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'Reinforcements spawned via SpawnLoadout. Con tracked as "reinforcement-con", wreck as "reinforcement-wreck".',
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
		type = actionTypes.DestroyFeature,
		parameters = {
			featureName = 'reinforcement-wreck',
		},
	},

	messageReinforcementsActedOn = {
		type = actionTypes.SendMessage,
		parameters = {
			message = 'Reinforcement con moved and wreck destroyed via names registered by SpawnLoadout.',
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
			allyTeamIDs = { 0 },
		},
	},
}

local unitLoadout = {
	-- Player team (team 0)
	{ name = 'armck',  x = 1780, z = 1850, facing = 'e', team = 0, unitName = 'player-con' },

	-- Enemy team (team 1)
	{ name = 'corsolar', x = 1700, z = 2150, facing = 'w', team = 1 },
	{ name = 'corsolar', x = 1800, z = 2150, facing = 's', team = 1 },
}

local featureLoadout = {
	{ name = 'corak_dead', x = 1900, z = 1800, facing = 's', resurrectAs = 'corcom', featureName = 'the-wreck' },
	{ name = 'armfus_dead', x = 1900, z = 2000, facing = 'e' },
}

return {
	Triggers       = triggers,
	Actions        = actions,
	UnitLoadout    = unitLoadout,
	FeatureLoadout = featureLoadout,
}
