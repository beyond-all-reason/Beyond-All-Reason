---
--- Resource triggers and actions test mission.
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local lobbyData = {
	missionId = "resource_test",
	title = "Resource Test",
	description = "Tests triggers and action related to resources, including adding resources, and triggers for stored resources, income, and pull.",
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

	-- ── Bootstrap ─────────────────────────────────────────────────────────────

	start = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 0,
		},
		actions = { 'spawnMetalStorage', 'spawnEnergyStorage' },
	},

	waveMetalAndEnergy = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 4,
		},
		actions = { 'addMetalAndEnergy', 'messageWaveMetalAndEnergy' },
	},

	waveMetalOnly = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 8,
		},
		actions = { 'addMetalOnly', 'messageWaveMetalOnly' },
	},

	waveEnergyOnly = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 12,
		},
		actions = { 'addEnergyOnly', 'messageWaveEnergyOnly' },
	},

	waveMex = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 16,
		},
		actions = { 'spawnMex', 'messageWaveMex' },
	},

	waveFusion = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 20,
		},
		actions = { 'spawnFusion', 'messageWaveFusion' },
	},

	waveMetalMaker = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 24,
		},
		actions = { 'spawnMetalMaker', 'messageWaveMetalMaker' },
	},

	waveNuke = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 30,
		},
		actions = { 'spawnNuke', 'messageWaveNuke' },
	},

	waveReclaim = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 32,
		},
		actions = { 'createWreckToReclaimIncome', 'spawnIncomeReclaimer', 'messageWaveReclaim' },
	},

	orderIncomeReclaimer = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 33,
		},
		actions = { 'orderIncomeReclaimerReclaim' },
	},

	waveUnitReclaim = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 36,
		},
		actions = { 'spawnUnitReclaimTarget', 'messageWaveUnitReclaim' },
	},

	orderUnitIncomeReclaimer = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 37,
		},
		actions = { 'orderUnitIncomeReclaimerReclaim' },
	},

	-- ── ResourceStored ────────────────────────────────────────────────────────

	enoughMetalStored = {
		type = triggerTypes.ResourceStored,
		parameters = {
			teamName = 'thePlayerTeam',
			metal = 1500,
		},
		actions = { 'messageMetalStored' },
	},

	enoughEnergyStored = {
		type = triggerTypes.ResourceStored,
		parameters = {
			teamName = 'thePlayerTeam',
			energy = 3000,
		},
		actions = { 'messageEnergyStored' },
	},

	bothResourcesStored = {
		type = triggerTypes.ResourceStored,
		parameters = {
			teamName = 'thePlayerTeam',
			metal = 1800,
			energy = 3500,
		},
		actions = { 'messageBothStored' },
	},

	-- ── ResourceIncome ────────────────────────────────────────────────────────

	metalIncomeReached = {
		type = triggerTypes.ResourceIncome,
		parameters = {
			teamName = 'thePlayerTeam',
			metal = 5,
		},
		actions = { 'messageMetalIncome' },
	},

	energyIncomeReached = {
		type = triggerTypes.ResourceIncome,
		parameters = {
			teamName = 'thePlayerTeam',
			energy = 500,
		},
		actions = { 'messageEnergyIncome' },
	},

	-- ── ResourceIncome (sources) ──────────────────────────────────────────────

	extractorMetalIncomeReached = {
		type = triggerTypes.ResourceIncome,
		parameters = {
			teamName = 'thePlayerTeam',
			metal = 1,
			sources = { 'extractor' },
		},
		actions = { 'messageExtractorMetalIncome' },
	},

	productionEnergyIncomeReached = {
		-- Triggered once armfus (second 20) is generating production energy income.
		type = triggerTypes.ResourceIncome,
		parameters = {
			teamName = 'thePlayerTeam',
			energy = 200,
			sources = { 'production' },
		},
		actions = { 'messageProductionEnergyIncome' },
	},

	productionMetalIncomeReached = {
		-- Triggered once armmmkr (second 24) is producing metal from energy.
		type = triggerTypes.ResourceIncome,
		parameters = {
			teamName = 'thePlayerTeam',
			metal = 0.5,
			sources = { 'production' },
		},
		actions = { 'messageProductionMetalIncome' },
	},

	multipleSourcesMetalIncomeReached = {
		-- Combined extractor + production metal income.
		type = triggerTypes.ResourceIncome,
		parameters = {
			teamName = 'thePlayerTeam',
			metal = 2,
			sources = { 'extractor', 'production' },
		},
		actions = { 'messageMultipleSourcesMetalIncome' },
	},

	reclaimMetalIncomeReached = {
		type = triggerTypes.ResourceIncome,
		parameters = {
			teamName = 'thePlayerTeam',
			metal = 0.1,
			sources = { 'reclaim' },
		},
		actions = { 'messageFeatureReclaimMetalIncome' },
	},

	unitReclaimMetalIncomeReached = {
		type = triggerTypes.ResourceIncome,
		parameters = {
			teamName = 'thePlayerTeam',
			metal = 70,
			sources = { 'reclaim' },
		},
		actions = { 'messageUnitReclaimMetalIncome' },
	},

	-- ── ResourcePull ──────────────────────────────────────────────────────────

	metalPullReached = {
		type = triggerTypes.ResourcePull,
		parameters = {
			teamName = 'thePlayerTeam',
			metal = 1,
		},
		actions = { 'messageMetalPull' },
	},

	energyPullReached = {
		type = triggerTypes.ResourcePull,
		parameters = {
			teamName = 'thePlayerTeam',
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
			unitLoadout = {
				{ unitDefName = 'armmstor', x = 1900, z = 1800, teamName = 'thePlayerTeam' },
			},
		},
	},

	spawnEnergyStorage = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armestor', x = 1900, z = 1900, teamName = 'thePlayerTeam' },
			},
		},
	},

	spawnMex = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armmex', x = 2220, z = 2210, teamName = 'thePlayerTeam' },
			},
		},
	},

	spawnFusion = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armfus', x = 1800, z = 1900, teamName = 'thePlayerTeam' },
			},
		},
	},

	spawnMetalMaker = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armmmkr', x = 1800, z = 2000, teamName = 'thePlayerTeam' },
			},
		},
	},

	spawnNuke = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'corsilo', x = 2000, z = 2110, teamName = 'thePlayerTeam' },
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
				{ unitDefName = 'armrectr', x = 2100, z = 2100, teamName = 'thePlayerTeam', unitName = 'incomeReclaimer' },
			},
		},
	},

	spawnUnitReclaimTarget = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armllt', x = 2200, z = 2100, teamName = 'thePlayerTeam', unitName = 'unitReclaimTarget' },
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
			teamName = 'thePlayerTeam',
			metal = 500,
			energy = 1000,
		},
	},

	-- ── AddResources (metal only) ─────────────────────────────────────────────

	addMetalOnly = {
		type = actionTypes.AddResources,
		parameters = {
			teamName = 'thePlayerTeam',
			metal = 250,
		},
	},

	-- ── AddResources (energy only) ────────────────────────────────────────────

	addEnergyOnly = {
		type = actionTypes.AddResources,
		parameters = {
			teamName = 'thePlayerTeam',
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
	LobbyData   = lobbyData,
	StartScript = startScript,
	Triggers = triggers,
	Actions = actions,
}
