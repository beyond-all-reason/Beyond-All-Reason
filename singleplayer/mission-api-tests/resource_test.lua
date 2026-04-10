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

	waveMex = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 480,
		},
		actions = { 'spawnMex', 'messageWaveMex' },
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

	waveReclaim = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 960,
		},
		actions = { 'createWreckToReclaimIncome', 'spawnIncomeReclaimer', 'messageWaveReclaim' },
	},

	orderIncomeReclaimer = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 990,
		},
		actions = { 'orderIncomeReclaimerReclaim' },
	},

	waveUnitReclaim = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 1080,
		},
		actions = { 'spawnUnitReclaimTarget', 'messageWaveUnitReclaim' },
	},

	orderUnitIncomeReclaimer = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			gameFrame = 1110,
		},
		actions = { 'orderUnitIncomeReclaimerReclaim' },
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
		},
		actions = { 'messageMetalIncome' },
	},

	energyIncomeReached = {
		type = triggerTypes.ResourceIncome,
		parameters = {
			teamID = 0,
			energy = 500,
		},
		actions = { 'messageEnergyIncome' },
	},

	-- ── ResourceIncome (sources) ──────────────────────────────────────────────

	extractorMetalIncomeReached = {
		type = triggerTypes.ResourceIncome,
		parameters = {
			teamID = 0,
			metal = 1,
			sources = { 'extractor' },
		},
		actions = { 'messageExtractorMetalIncome' },
	},

	productionEnergyIncomeReached = {
		-- Triggered once armfus (frame 600) is generating production energy income.
		type = triggerTypes.ResourceIncome,
		parameters = {
			teamID = 0,
			energy = 200,
			sources = { 'production' },
		},
		actions = { 'messageProductionEnergyIncome' },
	},

	productionMetalIncomeReached = {
		-- Triggered once armmmkr (frame 720) is producing metal from energy.
		type = triggerTypes.ResourceIncome,
		parameters = {
			teamID = 0,
			metal = 0.5,
			sources = { 'production' },
		},
		actions = { 'messageProductionMetalIncome' },
	},

	multipleSourcesMetalIncomeReached = {
		-- Combined extractor + production metal income.
		type = triggerTypes.ResourceIncome,
		parameters = {
			teamID = 0,
			metal = 2,
			sources = { 'extractor', 'production' },
		},
		actions = { 'messageMultipleSourcesMetalIncome' },
	},

	reclaimMetalIncomeReached = {
		type = triggerTypes.ResourceIncome,
		parameters = {
			teamID = 0,
			metal = 0.1,
			sources = { 'reclaim' },
		},
		actions = { 'messageFeatureReclaimMetalIncome' },
	},

	unitReclaimMetalIncomeReached = {
		type = triggerTypes.ResourceIncome,
		parameters = {
			teamID = 0,
			metal = 70,
			sources = { 'reclaim' },
		},
		actions = { 'messageUnitReclaimMetalIncome' },
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

	spawnMex = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitDefName = 'armmex',
			teamID = 0,
			position = { x = 2220, z = 2210 },
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
			position = { x = 2000, z = 2110 },
		},
	},

	createWreckToReclaimIncome = {
		type = actionTypes.CreateFeature,
		parameters = {
			featureDefName = 'armllt_dead',
			position = { x = 2100, z = 2000 },
			facing = 's',
		},
	},

	spawnIncomeReclaimer = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'incomeReclaimer',
			unitDefName = 'armrectr',
			teamID = 0,
			position = { x = 2100, z = 2100 },
		},
	},

	spawnUnitReclaimTarget = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitName = 'unitReclaimTarget',
			unitDefName = 'armllt',
			teamID = 0,
			position = { x = 2200, z = 2100 },
		},
	},

	orderIncomeReclaimerReclaim = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'incomeReclaimer',
			orders = {
				{ CMD.RECLAIM, { 2100, 0, 2000, 80 } },
			},
		},
	},

	orderUnitIncomeReclaimerReclaim = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'incomeReclaimer',
			orders = {
				{ CMD.RECLAIM, { unitName = 'unitReclaimTarget' } },
			},
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

	messageWaveMex = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Spawning Arm Metal Extractor (armmex).",
		},
	},

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

	messageWaveReclaim = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Spawning Arm LLT wreck and reclaimer.",
		},
	},

	messageWaveUnitReclaim = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Spawning Arm LLT unit and reclaimer.",
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
			message = "[Resource Test] Adding 250 metal.",
		},
	},

	messageWaveEnergyOnly = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Adding 500 energy.",
		},
	},

	-- ── ResourceStored messages ───────────────────────────────────────────────

	messageMetalStored = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] has >= 1500 metal stored.",
		},
	},

	messageEnergyStored = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] has >= 3000 energy stored.",
		},
	},

	messageBothStored = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] has >= 1800 metal AND >= 3500 energy stored.",
		},
	},

	-- ── ResourceIncome messages ───────────────────────────────────────────────

	messageMetalIncome = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] metal income >= 5 m/s.",
		},
	},

	messageEnergyIncome = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] energy income >= 500 e/s.",
		},
	},

	-- ── ResourceIncome (sources) messages ────────────────────────────────────

	messageExtractorMetalIncome = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] extractor metal income >= 1 m/s.",
		},
	},

	messageProductionEnergyIncome = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] production energy income >= 200 e/s.",
		},
	},

	messageProductionMetalIncome = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] production metal income >= 0.5 m/s.",
		},
	},

	messageMultipleSourcesMetalIncome = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] extractor+production metal income >= 2 m/s.",
		},
	},

	messageFeatureReclaimMetalIncome = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] feature reclaim metal income >= 0.1 m/s.",
		},
	},

	messageUnitReclaimMetalIncome = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] unit reclaim metal income >= 70 m/s.",
		},
	},

	-- ── ResourcePull messages ─────────────────────────────────────────────────

	messageMetalPull = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] metal pull >= 1 m/s.",
		},
	},

	messageEnergyPull = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] energy pull >= 100 e/s.",
		},
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
