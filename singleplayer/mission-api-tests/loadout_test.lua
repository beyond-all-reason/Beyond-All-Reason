---
--- Test mission demonstrating UnitLoadout and FeatureLoadout.
---

local conditionTypes   = GG['MissionAPI'].ConditionDefinitions.Types
local actionTypes    = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	intro = {
		type = conditionTypes.TimeElapsed,
		parameters = {
			seconds = 0,
		},
		actions = { 'messageIntro' },
	},

	movePlayerCon = {
		type = conditionTypes.TimeElapsed,
		parameters = {
			seconds = 2,
		},
		actions = { 'movePlayerCon' },
	},

	destroyWreck = {
		type = conditionTypes.TimeElapsed,
		parameters = {
			seconds = 4,
		},
		actions = { 'destroyWreck', 'messageWreckDestroyed' },
	},

	spawnReinforcements = {
		type = conditionTypes.TimeElapsed,
		parameters = {
			seconds = 7,
		},
		actions = { 'spawnReinforcements', 'createFeatures', 'messageReinforcementsArrived' },
	},

	actOnReinforcements = {
		type = conditionTypes.TimeElapsed,
		parameters = {
			seconds = 10,
		},
		actions = { 'moveReinforcements', 'destroyReinforcementWreck', 'messageReinforcementsActedOn' },
	},

	victory = {
		type = conditionTypes.TimeElapsed,
		parameters = {
			seconds = 20,
		},
		actions = { 'messageEnd', 'victory' },
	},
}

local actions = {

	messageIntro = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = 'Loadout test: pre-spawned units and features are live. ' ..
			          'Player con has an initial patrol order from loadout. ' ..
			          'The wreck (featureName="the-wreck") will be destroyed. ' ..
			          'The wreck east of it faces east-northeast (angle 60). ' ..
			          'The tank west of the cons faces north-east (angle 45). ' ..
			          'The third enemy solar stands east though its angle is 100: buildings keep the four facings.',
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
			messageKey = 'Wreck destroyed via featureName tracking.',
		},
	},

	spawnReinforcements = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armck',   position = { x = 1900, z = 1700 }, orientation = 'e', teamName = 'player', unitName = 'reinforcement-con' },
				{ unitDefName = 'armflea', position = { x = 1900, z = 1820 }, orientation = 'e', teamName = 'player',
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
				{ featureDefName = 'corak_dead', position = { x = 1800, z = 1750 }, orientation = 's', featureName = 'reinforcement-wreck' },
				{ featureDefName = 'corak_dead', position = { x = 2000, z = 1700 }, orientation = { x = 1900, z = 1700 } },
			},
		},
	},

	messageReinforcementsArrived = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = 'Reinforcements spawned via SpawnUnits + CreateFeatures. Con tracked as "reinforcement-con", wreck as "reinforcement-wreck". ' ..
				'The wreck east of the con faces it (facing a point).',
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
			messageKey = 'Reinforcement con moved and wreck destroyed via names registered by SpawnUnits + CreateFeatures.',
		},
	},

	messageEnd = {
		type = actionTypes.SendMessage,
		parameters = {
			messageKey = 'Loadout test complete.',
		},
	},

	victory = {
		type = actionTypes.Victory,
		parameters = {
			allianceNames = { 'players' },
		},
	},
}

local unitLoadout    = {
	-- Player team (team 0).
	{ unitDefName = 'armck', position = { x = 1780, z = 1850 }, orientation = 'e', teamName = 'player', unitName = 'player-con' },
	{ unitDefName = 'corck', position = { x = 1780, z = 1800 }, orientation = 'e', teamName = 'player',
	  orders = {
	    { CMD.PATROL, { 1780, 0, 1950 }, {} },
	  },
	},
	-- A lab in a ring of dragon's teeth, each tooth 16 elmos clear of the lab, open to the south.
	{ unitDefName = 'armlab',  position = { x = 1520, z = 1600 }, orientation = 's', teamName = 'player' },
	{ unitDefName = 'armdrag', position = { x = 1440, z = 1520 }, teamName = 'player' },
	{ unitDefName = 'armdrag', position = { x = 1520, z = 1520 }, teamName = 'player' },
	{ unitDefName = 'armdrag', position = { x = 1600, z = 1520 }, teamName = 'player' },
	{ unitDefName = 'armdrag', position = { x = 1440, z = 1600 }, teamName = 'player' },
	{ unitDefName = 'armdrag', position = { x = 1600, z = 1600 }, teamName = 'player' },
	{ unitDefName = 'armdrag', position = { x = 1440, z = 1680 }, teamName = 'player' },
	{ unitDefName = 'armdrag', position = { x = 1600, z = 1680 }, teamName = 'player' },
	-- A unit that moves turns to any angle.
	{ unitDefName = 'armflash', position = { x = 1680, z = 1850 }, orientation = { angle = 45 }, teamName = 'player' },

	-- Enemy team (team 1)
	{ unitDefName = 'corsolar', position = { x = 1700, z = 2150 }, orientation = 'w', teamName = 'enemy' },
	{ unitDefName = 'corsolar', position = { x = 1800, z = 2150 }, orientation = 's', teamName = 'enemy' },
	-- A building keeps the nearest of the four facings: angle 100 stands east.
	{ unitDefName = 'corsolar', position = { x = 2000, z = 2150 }, orientation = { angle = 100 }, teamName = 'enemy' },
  
	-- Gaia's team
	{ unitDefName = 'corsolar', position = { x = 1900, z = 2150 }, orientation = 's', teamName = 'gaia' },
}

local featureLoadout = {
	{ featureDefName = 'corak_dead',  position = { x = 1900, z = 1800 }, orientation = 's', featureName = 'the-wreck' },
	{ featureDefName = 'corak_dead',  position = { x = 2000, z = 1800 }, orientation = { angle = 60 } },
	{ featureDefName = 'armfus_dead', position = { x = 1900, z = 2000 }, orientation = 'e' },
}

return {
	Triggers       = triggers,
	Actions        = actions,
	UnitLoadout    = unitLoadout,
	FeatureLoadout = featureLoadout,
}
