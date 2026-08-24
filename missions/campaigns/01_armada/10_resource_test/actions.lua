local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

return {
	Actions = {

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

		-- ── AddResources (Remove) (metal + energy together) ────────────────────────────────

		removeMetalAndEnergy = {
			type = actionTypes.AddResources,
			parameters = {
				teamName = 'thePlayerTeam',
				metal = -500,
				energy = -1000,
			},
		},

		-- ── AddResources (Remove) (metal only) ─────────────────────────────────────────────

		removeMetalOnly = {
			type = actionTypes.AddResources,
			parameters = {
				teamName = 'thePlayerTeam',
				metal = -250,
			},
		},

		-- ── AddResources (Remove) (energy only) ────────────────────────────────────────────

		removeEnergyOnly = {
			type = actionTypes.AddResources,
			parameters = {
				teamName = 'thePlayerTeam',
				energy = -500,
			},
		},

		-- ── AddResources (Per Second) (metal + energy together) ────────────────────────────────

		addMetalAndEnergyPerSecond = {
			type = actionTypes.AddResourcesPerSecond,
			parameters = {
				teamName = 'thePlayerTeam',
				metal = 50,
				energy = 2000,
			},
		},

		-- ── AddResources (Remove) (Per Second) (metal + energy together) ────────────────────────────────

		removeMetalAndEnergyPerSecond = {
			type = actionTypes.AddResourcesPerSecond,
			parameters = {
				teamName = 'thePlayerTeam',
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
	},
}
