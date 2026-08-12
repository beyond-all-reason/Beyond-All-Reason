---
--- Resource triggers and actions test mission.
---

local eventTypes  = GG['MissionAPI'].ConditionDefinitions.EventTypes
local metricTypes = GG['MissionAPI'].ConditionDefinitions.MetricTypes
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local triggers = {

	-- ── Bootstrap ─────────────────────────────────────────────────────────────

	start = {
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 0,
		},
		actions = { 'spawnMetalStorage', 'spawnEnergyStorage' },
	},

	waveMetalAndEnergy = {
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 4,
		},
		actions = { 'addMetalAndEnergy', 'messageWaveMetalAndEnergy' },
	},

	waveMetalAndEnergyRemove = {
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 6,
		},
		actions = { 'removeMetalAndEnergy', 'messageWaveMetalAndEnergyRemove' },
	},

	waveMetalOnly = {
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 8,
		},
		actions = { 'addMetalOnly', 'messageWaveMetalOnly' },
	},

	waveMetalOnlyRemove = {
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 10,
		},
		actions = { 'removeMetalOnly', 'messageWaveMetalOnlyRemove' },
	},

	waveEnergyOnly = {
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 12,
		},
		actions = { 'addEnergyOnly', 'messageWaveEnergyOnly' },
	},

	waveEnergyOnlyRemove = {
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 14,
		},
		actions = { 'removeEnergyOnly', 'messageWaveEnergyOnlyRemove' },
	},

	waveMex = {
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 16,
		},
		actions = { 'spawnMex', 'messageWaveMex' },
	},

	waveFusion = {
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 20,
		},
		actions = { 'spawnFusion', 'messageWaveFusion' },
	},

	waveMetalMaker = {
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 24,
		},
		actions = { 'spawnMetalMaker', 'messageWaveMetalMaker' },
	},

	waveNuke = {
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 30,
		},
		actions = { 'spawnNuke', 'messageWaveNuke' },
	},

	waveReclaim = {
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 32,
		},
		actions = { 'createWreckToReclaimIncome', 'spawnIncomeReclaimer', 'messageWaveReclaim' },
	},

	orderIncomeReclaimer = {
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 33,
		},
		actions = { 'orderIncomeReclaimerReclaim' },
	},

	waveUnitReclaim = {
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 36,
		},
		actions = { 'spawnUnitReclaimTarget', 'messageWaveUnitReclaim' },
	},

	orderUnitIncomeReclaimer = {
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 37,
		},
		actions = { 'orderUnitIncomeReclaimerReclaim' },
	},

	waveMetalAndEnergyPerSecond = {
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 40,
		},
		actions = { 'addMetalAndEnergyPerSecond', 'messageWaveMetalAndEnergyPerSecond'},
	},

	waveMetalAndEnergyPerSecondRemove = {
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 47,
		},
		actions = { 'removeMetalAndEnergyPerSecond', 'messageWaveMetalAndEnergyPerSecondRemove'},
	},

	waveMetalAndEnergyPerSecond2 = {
		type = eventTypes.TimeElapsed,
		parameters = {
			seconds = 54,
		},
		actions = { 'addMetalAndEnergyPerSecond', 'messageWaveMetalAndEnergyPerSecond'},
	},

	-- ── ResourceStored ────────────────────────────────────────────────────────

	enoughMetalStored = {
		type = metricTypes.ResourceStored,
		parameters = {
			teamID = 0,
			resource = 'metal',
		},
		atLeast = 1500,
		actions = { 'messageMetalStored' },
	},

	enoughEnergyStored = {
		type = metricTypes.ResourceStored,
		parameters = {
			teamID = 0,
			resource = 'energy',
		},
		atLeast = 3000,
		actions = { 'messageEnergyStored' },
	},

	-- A metric measures one value, so "metal AND energy" is two conditions
	-- chained by a prerequisite rather than one condition with two thresholds.
	enoughMetalForBoth = {
		type = metricTypes.ResourceStored,
		parameters = {
			teamID = 0,
			resource = 'metal',
		},
		atLeast = 1800,
		actions = { 'messageMetalForBoth' },
	},

	bothResourcesStored = {
		type = metricTypes.ResourceStored,
		parameters = {
			teamID = 0,
			resource = 'energy',
		},
		atLeast = 3500,
		settings = {
			prerequisites = { 'enoughMetalForBoth' },
		},
		actions = { 'messageBothStored' },
	},

	-- ── ResourceIncome ────────────────────────────────────────────────────────

	metalIncomeReached = {
		type = metricTypes.ResourceIncome,
		parameters = {
			teamID = 0,
			resource = 'metal',
		},
		atLeast = 5,
		actions = { 'messageMetalIncome' },
	},

	energyIncomeReached = {
		type = metricTypes.ResourceIncome,
		parameters = {
			teamID = 0,
			resource = 'energy',
		},
		atLeast = 500,
		actions = { 'messageEnergyIncome' },
	},

	-- ── ResourceIncome (sources) ──────────────────────────────────────────────

	extractorMetalIncomeReached = {
		type = metricTypes.ResourceIncome,
		parameters = {
			teamID = 0,
			resource = 'metal',
			sources = { 'extractor' },
		},
		atLeast = 1,
		actions = { 'messageExtractorMetalIncome' },
	},

	productionEnergyIncomeReached = {
		-- Triggered once armfus (second 20) is generating production energy income.
		type = metricTypes.ResourceIncome,
		parameters = {
			teamID = 0,
			resource = 'energy',
			sources = { 'production' },
		},
		atLeast = 200,
		actions = { 'messageProductionEnergyIncome' },
	},

	productionMetalIncomeReached = {
		-- Triggered once armmmkr (second 24) is producing metal from energy.
		type = metricTypes.ResourceIncome,
		parameters = {
			teamID = 0,
			resource = 'metal',
			sources = { 'production' },
		},
		atLeast = 0.5,
		actions = { 'messageProductionMetalIncome' },
	},

	multipleSourcesMetalIncomeReached = {
		-- Combined extractor + production metal income.
		type = metricTypes.ResourceIncome,
		parameters = {
			teamID = 0,
			resource = 'metal',
			sources = { 'extractor', 'production' },
		},
		atLeast = 2,
		actions = { 'messageMultipleSourcesMetalIncome' },
	},

	reclaimMetalIncomeReached = {
		type = metricTypes.ResourceIncome,
		parameters = {
			teamID = 0,
			resource = 'metal',
			sources = { 'reclaim' },
		},
		atLeast = 0.1,
		actions = { 'messageFeatureReclaimMetalIncome' },
	},

	unitReclaimMetalIncomeReached = {
		type = metricTypes.ResourceIncome,
		parameters = {
			teamID = 0,
			resource = 'metal',
			sources = { 'reclaim' },
		},
		atLeast = 70,
		actions = { 'messageUnitReclaimMetalIncome' },
	},

	-- ── ResourcePull ──────────────────────────────────────────────────────────

	metalPullReached = {
		type = metricTypes.ResourcePull,
		parameters = {
			teamID = 0,
			resource = 'metal',
		},
		atLeast = 1,
		actions = { 'messageMetalPull' },
	},

	energyPullReached = {
		type = metricTypes.ResourcePull,
		parameters = {
			teamID = 0,
			resource = 'energy',
		},
		atLeast = 100,
		actions = { 'messageEnergyPull' },
	},
}

local actions = {

	-- ── Setup ─────────────────────────────────────────────────────────────────

	spawnMetalStorage = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armmstor', x = 1900, z = 1800, team = 0 },
			},
		},
	},

	spawnEnergyStorage = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armestor', x = 1900, z = 1900, team = 0 },
			},
		},
	},

	spawnMex = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armmex', x = 2220, z = 2210, team = 0 },
			},
		},
	},

	spawnFusion = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armfus', x = 1800, z = 1900, team = 0 },
			},
		},
	},

	spawnMetalMaker = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armmmkr', x = 1800, z = 2000, team = 0 },
			},
		},
	},

	spawnNuke = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'corsilo', x = 2000, z = 2110, team = 0 },
			},
		},
	},

	createWreckToReclaimIncome = {
		type = actionTypes.CreateFeatures,
		parameters = {
			featureLoadout = {
				{ featureDefName = 'armllt_dead', x = 2100, z = 2000, facing = 's' },
			},
		},
	},

	spawnIncomeReclaimer = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armrectr', x = 2100, z = 2100, team = 0, unitName = 'incomeReclaimer' },
			},
		},
	},

	spawnUnitReclaimTarget = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armllt', x = 2200, z = 2100, team = 0, unitName = 'unitReclaimTarget' },
			},
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

	-- ── AddResources (Remove) (metal + energy together) ────────────────────────────────

	removeMetalAndEnergy = {
		type = actionTypes.AddResources,
		parameters = {
			teamID = 0,
			metal = -500,
			energy = -1000,
		},
	},

	-- ── AddResources (Remove) (metal only) ─────────────────────────────────────────────

	removeMetalOnly = {
		type = actionTypes.AddResources,
		parameters = {
			teamID = 0,
			metal = -250,
		},
	},

	-- ── AddResources (Remove) (energy only) ────────────────────────────────────────────

	removeEnergyOnly = {
		type = actionTypes.AddResources,
		parameters = {
			teamID = 0,
			energy = -500,
		},
	},

	-- ── AddResources (Per Second) (metal + energy together) ────────────────────────────────

	addMetalAndEnergyPerSecond = {
		type = actionTypes.AddResourcesPerSecond,
		parameters = {
			teamID = 0,
			metal = 50,
			energy = 2000,
		},
	},

	-- ── AddResources (Remove) (Per Second) (metal + energy together) ────────────────────────────────

	removeMetalAndEnergyPerSecond = {
		type = actionTypes.AddResourcesPerSecond,
		parameters = {
			teamID = 0,
			metal = -75,
			energy = -2500,
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

	messageWaveMetalAndEnergyRemove = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Removing 500 metal and 1000 energy.",
		},
	},

	messageWaveMetalOnlyRemove = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Removing 250 metal.",
		},
	},

	messageWaveEnergyOnlyRemove = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Removing 500 energy.",
		},
	},

	messageWaveMetalAndEnergyPerSecond = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Adding 50 metal and 2000 energy per second.",
		},
	},

	messageWaveMetalAndEnergyPerSecondRemove = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] Removing 75 metal and 2500 energy per second.",
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

	messageMetalForBoth = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "[Resource Test] has >= 1800 metal (half of the combined check).",
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
