---
--- Resource triggers and actions test mission.
---

local triggerTypes = GG['MissionAPI'].TriggerTypes
local actionTypes = GG['MissionAPI'].ActionTypes

local triggers = {

	-- ── Bootstrap ─────────────────────────────────────────────────────────────

	start = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 1,
		},
		actions = { 'spawnMetalStorage', 'spawnEnergyStorage' },
	},

	waveMetalAndEnergy = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 120,
		},
		actions = { 'addMetalAndEnergy', 'messageWaveMetalAndEnergy' },
	},

	waveMetalOnly = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 240,
		},
		actions = { 'addMetalOnly', 'messageWaveMetalOnly' },
	},

	waveEnergyOnly = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 360,
		},
		actions = { 'addEnergyOnly', 'messageWaveEnergyOnly' },
	},

	waveFusion = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 600,
		},
		actions = { 'spawnFusion', 'messageWaveFusion' },
	},

	waveMetalMaker = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 720,
		},
		actions = { 'spawnMetalMaker', 'messageWaveMetalMaker' },
	},

	waveNuke = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 900,
		},
		actions = { 'spawnNuke', 'messageWaveNuke' },
	},

	-- ── ResourceStored ────────────────────────────────────────────────────────

	enoughMetalStored = {
		type = triggerTypes.ResourceStored,
		parameters = {
			teamID = 0,
			metal = 1500,
		},
		actions = { 'messageMetalStored' },
	},

	enoughEnergyStored = {
		type = triggerTypes.ResourceStored,
		parameters = {
			teamID = 0,
			energy = 3000,
		},
		actions = { 'messageEnergyStored' },
	},

	bothResourcesStored = {
		type = triggerTypes.ResourceStored,
		parameters = {
			teamID = 0,
			metal = 1800,
			energy = 3500,
		},
		actions = { 'messageBothStored' },
	},

	-- ── ResourceIncome ────────────────────────────────────────────────────────

	metalIncomeReached = {
		type = triggerTypes.ResourceIncome,
		parameters = {
			teamID = 0,
			metal = 5,
			stableFrames = 150,
		},
		actions = { 'messageMetalIncome' },
	},

	energyIncomeReached = {
		type = triggerTypes.ResourceIncome,
		parameters = {
			teamID = 0,
			energy = 500,
			stableFrames = 150,
		},
		actions = { 'messageEnergyIncome' },
	},

	-- ── ResourcePull ──────────────────────────────────────────────────────────

	metalPullReached = {
		type = triggerTypes.ResourcePull,
		parameters = {
			teamID = 0,
			metal = 1,
		},
		actions = { 'messageMetalPull' },
	},

	energyPullReached = {
		type = triggerTypes.ResourcePull,
		parameters = {
			teamID = 0,
			energy = 100,
		},
		actions = { 'messageEnergyPull' },
	},
}

local actions = {

	-- ── Setup ─────────────────────────────────────────────────────────────────

	spawnMetalStorage = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitDefName = 'armmstor',
			teamID = 0,
			position = { x = 1900, z = 1800 },
		},
	},

	spawnEnergyStorage = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitDefName = 'armestor',
			teamID = 0,
			position = { x = 1900, z = 1900 },
		},
	},

	spawnFusion = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitDefName = 'armfus',
			teamID = 0,
			position = { x = 1800, z = 1900 },
		},
	},

	spawnMetalMaker = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitDefName = 'armmmkr',
			teamID = 0,
			position = { x = 1800, z = 2000 },
		},
	},

	spawnNuke = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitDefName = 'corsilo',
			teamID = 0,
			position = { x = 2000, z = 2100 },
		},
	},

	-- ── AddResources (metal + energy together) ────────────────────────────────

	addMetalAndEnergy = {
		type = actionTypes.AddResources,
		parameters = {
			teamID = 0,
			metal = 500,
			energy = 1000,
		},
	},

	-- ── AddResources (metal only) ─────────────────────────────────────────────

	addMetalOnly = {
		type = actionTypes.AddResources,
		parameters = {
			teamID = 0,
			metal = 250,
		},
	},

	-- ── AddResources (energy only) ────────────────────────────────────────────

	addEnergyOnly = {
		type = actionTypes.AddResources,
		parameters = {
			teamID = 0,
			energy = 500,
		},
	},

	-- ── Wave messages ─────────────────────────────────────────────────────────

	messageWaveFusion = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Spawning Arm Fusion Reactor (armfus).",
		},
	},

	messageWaveMetalMaker = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Spawning Arm Advanced Metal Maker (armmmkr).",
		},
	},

	messageWaveNuke = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Spawning Core Silo (corsilo).",
		},
	},

	messageWaveMetalAndEnergy = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Adding 500 metal and 1000 energy.",
		},
	},

	messageWaveMetalOnly = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Adding 250 metal only.",
		},
	},

	messageWaveEnergyOnly = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Adding 2000 energy only.",
		},
	},

	-- ── ResourceStored messages ───────────────────────────────────────────────

	messageMetalStored = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Team 0 has >= 1500 metal stored.",
		},
	},

	messageEnergyStored = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Team 0 has >= 3000 energy stored.",
		},
	},

	messageBothStored = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Team 0 has >= 2000 metal AND >= 5000 energy stored.",
		},
	},

	-- ── ResourceIncome messages ───────────────────────────────────────────────

	messageMetalIncome = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Team 0 metal income >= 5 m/s.",
		},
	},

	messageEnergyIncome = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Team 0 energy income >= 500 e/s.",
		},
	},

	-- ── ResourcePull messages ─────────────────────────────────────────────────

	messageMetalPull = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Team 0 metal pull >= 1 m/s.",
		},
	},

	messageEnergyPull = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Team 0 energy pull >= 100 e/s.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
