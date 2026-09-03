local triggerTypes = GG["MissionAPI"].TriggerDefinitions.Types

return {
	Triggers = {

		-- ── Bootstrap ─────────────────────────────────────────────────────────────

		start = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 0,
			},
			actions = { "spawnMetalStorage", "spawnEnergyStorage" },
		},

		waveMetalAndEnergy = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 4,
			},
			actions = { "addMetalAndEnergy", "messageWaveMetalAndEnergy" },
		},

		waveMetalAndEnergyRemove = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 6,
			},
			actions = { "removeMetalAndEnergy", "messageWaveMetalAndEnergyRemove" },
		},

		waveMetalOnly = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 8,
			},
			actions = { "addMetalOnly", "messageWaveMetalOnly" },
		},

		waveMetalOnlyRemove = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 10,
			},
			actions = { "removeMetalOnly", "messageWaveMetalOnlyRemove" },
		},

		waveEnergyOnly = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 12,
			},
			actions = { "addEnergyOnly", "messageWaveEnergyOnly" },
		},

		waveEnergyOnlyRemove = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 14,
			},
			actions = { "removeEnergyOnly", "messageWaveEnergyOnlyRemove" },
		},

		waveMex = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 16,
			},
			actions = { "spawnMex", "messageWaveMex" },
		},

		waveFusion = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 20,
			},
			actions = { "spawnFusion", "messageWaveFusion" },
		},

		waveMetalMaker = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 24,
			},
			actions = { "spawnMetalMaker", "messageWaveMetalMaker" },
		},

		waveNuke = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 30,
			},
			actions = { "spawnNuke", "messageWaveNuke" },
		},

		waveReclaim = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 32,
			},
			actions = { "createWreckToReclaimIncome", "spawnIncomeReclaimer", "messageWaveReclaim" },
		},

		orderIncomeReclaimer = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 33,
			},
			actions = { "orderIncomeReclaimerReclaim" },
		},

		waveUnitReclaim = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 36,
			},
			actions = { "spawnUnitReclaimTarget", "messageWaveUnitReclaim" },
		},

		orderUnitIncomeReclaimer = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 37,
			},
			actions = { "orderUnitIncomeReclaimerReclaim" },
		},

		waveMetalAndEnergyPerSecond = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 40,
			},
			actions = { "addMetalAndEnergyPerSecond", "messageWaveMetalAndEnergyPerSecond" },
		},

		waveMetalAndEnergyPerSecondRemove = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 47,
			},
			actions = { "removeMetalAndEnergyPerSecond", "messageWaveMetalAndEnergyPerSecondRemove" },
		},

		waveMetalAndEnergyPerSecond2 = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 54,
			},
			actions = { "addMetalAndEnergyPerSecond", "messageWaveMetalAndEnergyPerSecond" },
		},

		-- ── ResourceStored ────────────────────────────────────────────────────────

		enoughMetalStored = {
			type = triggerTypes.ResourceStored,
			parameters = {
				teamName = "thePlayerTeam",
				metal = 1500,
			},
			actions = { "messageMetalStored" },
		},

		enoughEnergyStored = {
			type = triggerTypes.ResourceStored,
			parameters = {
				teamName = "thePlayerTeam",
				energy = 3000,
			},
			actions = { "messageEnergyStored" },
		},

		bothResourcesStored = {
			type = triggerTypes.ResourceStored,
			parameters = {
				teamName = "thePlayerTeam",
				metal = 1800,
				energy = 3500,
			},
			actions = { "messageBothStored" },
		},

		-- ── ResourceIncome ────────────────────────────────────────────────────────

		metalIncomeReached = {
			type = triggerTypes.ResourceIncome,
			parameters = {
				teamName = "thePlayerTeam",
				metal = 5,
			},
			actions = { "messageMetalIncome" },
		},

		energyIncomeReached = {
			type = triggerTypes.ResourceIncome,
			parameters = {
				teamName = "thePlayerTeam",
				energy = 500,
			},
			actions = { "messageEnergyIncome" },
		},

		-- ── ResourceIncome (sources) ──────────────────────────────────────────────

		extractorMetalIncomeReached = {
			type = triggerTypes.ResourceIncome,
			parameters = {
				teamName = "thePlayerTeam",
				metal = 1,
				sources = { "extractor" },
			},
			actions = { "messageExtractorMetalIncome" },
		},

		productionEnergyIncomeReached = {
			-- Triggered once armfus (second 20) is generating production energy income.
			type = triggerTypes.ResourceIncome,
			parameters = {
				teamName = "thePlayerTeam",
				energy = 200,
				sources = { "production" },
			},
			actions = { "messageProductionEnergyIncome" },
		},

		productionMetalIncomeReached = {
			-- Triggered once armmmkr (second 24) is producing metal from energy.
			type = triggerTypes.ResourceIncome,
			parameters = {
				teamName = "thePlayerTeam",
				metal = 0.5,
				sources = { "production" },
			},
			actions = { "messageProductionMetalIncome" },
		},

		multipleSourcesMetalIncomeReached = {
			-- Combined extractor + production metal income.
			type = triggerTypes.ResourceIncome,
			parameters = {
				teamName = "thePlayerTeam",
				metal = 2,
				sources = { "extractor", "production" },
			},
			actions = { "messageMultipleSourcesMetalIncome" },
		},

		reclaimMetalIncomeReached = {
			type = triggerTypes.ResourceIncome,
			parameters = {
				teamName = "thePlayerTeam",
				metal = 0.1,
				sources = { "reclaim" },
			},
			actions = { "messageFeatureReclaimMetalIncome" },
		},

		unitReclaimMetalIncomeReached = {
			type = triggerTypes.ResourceIncome,
			parameters = {
				teamName = "thePlayerTeam",
				metal = 70,
				sources = { "reclaim" },
			},
			actions = { "messageUnitReclaimMetalIncome" },
		},

		-- ── ResourcePull ──────────────────────────────────────────────────────────

		metalPullReached = {
			type = triggerTypes.ResourcePull,
			parameters = {
				teamName = "thePlayerTeam",
				metal = 1,
			},
			actions = { "messageMetalPull" },
		},

		energyPullReached = {
			type = triggerTypes.ResourcePull,
			parameters = {
				teamName = "thePlayerTeam",
				energy = 100,
			},
			actions = { "messageEnergyPull" },
		},
	},
}
