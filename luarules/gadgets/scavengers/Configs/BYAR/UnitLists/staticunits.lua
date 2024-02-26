local function getUnitIDList(unitNameList)
	local unitDefIDList = {}
	for _, unitName in ipairs(unitNameList) do
		local unitDefID = UnitDefNames[unitName].id
		unitDefIDList[unitDefID] = true
	end

	return unitDefIDList
end

local scavSpawnEffectUnit = "scavengerdroppod_scav"
local scavSpawnBeacon = "scavengerdroppodbeacon_scav"
local friendlySpawnEffectUnit = "scavengerdroppodfriendly"

local scavSpawnEffectUnitID = UnitDefNames[scavSpawnEffectUnit].id
local scavSpawnBeaconID = UnitDefNames[scavSpawnBeacon].id
local friendlySpawnEffectUnitID = UnitDefNames[friendlySpawnEffectUnit].id

local noSelfDestruct = {
	"cortex_dragonsmaw_scav",
	"armada_dragonsclaw_scav",
	"corfmd_scav",
	"armada_citadel_scav",
	"lootboxgold_scav",
	"lootboxplatinum_scav",
	"lootboxsilver_scav",
	"lootboxbronze_scav",
	"raptor_turrets",
	"raptor_hive",
	"corscavdtl_scav",
	"corscavdtf_scav",
	"corscavdtm_scav",
}

local walls = {
	"armada_dragonsteeth_scav",
	"armada_sharksteeth_scav",
	"cortex_dragonsteeth_scav",
	"cortex_sharksteeth_scav",
	"armada_fortificationwall_scav",
	"cortex_fortificationwall_scav",
	"corscavdrag_scav",
	"corscavfort_scav",
}

local stockpilers = {
	"cortex_apocalypse_scav",
	"armada_armageddon_scav",
	"cortex_catalyst_scav",
	"armada_paralyzer_scav",
	"armada_citadel_scav",
	"corfmd_scav",
	"cortex_screamer_scav",
	"armada_mercury_scav",
	"cortex_juno_scav",
	"armada_juno_scav",
	"armada_thor_scav",
	"armada_umbrella_scav",
	"cormabm_scav",
	"armada_haven_scav",
	"cortex_oasis_scav",
	"armbotrail_scav",
}

local nukes = {
	"cortex_apocalypse_scav",
	"armada_armageddon_scav",
	"cortex_catalyst_scav",
	"armada_paralyzer_scav",
	"cortex_juno_scav",
	"armada_juno_scav",
}

local beaconCaptureExclusions = {
	"armada_dragonsteeth",
	"armada_sharksteeth",
	"cortex_dragonsteeth",
	"cortex_sharksteeth",
	"armada_fortificationwall",
	"cortex_fortificationwall",
}

local beaconDefencesLand = {
	T0 = {
		-- Nanos
		"armada_constructionturret_scav",
		"cortex_constructionturret_scav",

		-- T0
		"armada_sentry_scav",
		"armada_nettle_scav",
		"cortex_guard_scav",
		"cortex_thistle_scav",
	},

	T1 = {
		-- Nanos
		"armada_constructionturret_scav",
		"cortex_constructionturret_scav",

		-- T1
		"armada_radartower_scav",
		"armada_sneakypete_scav",
		"armada_beamer_scav",
		"armada_overwatch_scav",
		"armada_gauntlet_scav",
		"legmg_scav",
		"armada_nettle_scav",
		"armada_ferret_scav",
		"armada_chainsaw_scav",
		"armada_anemone_scav",
		"cortex_radartower_scav",
		"cortex_castro_scav",
		"cortex_twinguard_scav",
		"cortex_warden_scav",
		"cortex_agitator_scav",
		"cortex_sam_scav",
		"cortex_eradicator_scav",
		"cortex_jellyfish_scav",
		"corscavdtl_scav",
		"corscavdtf_scav",
		"corscavdtm_scav",
	},

	T2 = {
		-- Nanos
		"armada_constructionturret_scav",
		"cortex_constructionturret_scav",

		-- T1
		"armada_radartower_scav",
		"armada_sneakypete_scav",
		"armada_beamer_scav",
		"armada_overwatch_scav",
		"armada_gauntlet_scav",
		"legmg_scav",
		"armada_nettle_scav",
		"armada_ferret_scav",
		"armada_chainsaw_scav",
		"armada_anemone_scav",
		"cortex_radartower_scav",
		"cortex_castro_scav",
		"cortex_twinguard_scav",
		"cortex_warden_scav",
		"cortex_agitator_scav",
		"cortex_sam_scav",
		"cortex_eradicator_scav",
		"cortex_jellyfish_scav",
		"corscavdtl_scav",
		"corscavdtf_scav",
		"corscavdtm_scav",
		
		-- Nanos
		"armada_constructionturret_scav",
		"cortex_constructionturret_scav",

		-- T2
		"armada_advancedradartower_scav",
		"armada_veil_scav",
		"armada_tracer_scav",
		"armada_pinpointer_scav",
		"armada_keeper_scav",
		"armada_pitbull_scav",
		"armada_rattlesnake_scav",
		"armada_arbalest_scav",
		"cortex_advancedradartower_scav",
		"cortex_shroud_scav",
		"cortex_nemesis_scav",
		"cortex_pinpointer_scav",
		"cortex_overseer_scav",
		"corhllllt_scav",
		"cortex_scorpion_scav",
		"cortex_persecutor_scav",
		"corflak_scav",
	},

	T3 = {
		-- Nanos
		"armada_constructionturret_scav",
		"cortex_constructionturret_scav",

		-- T2
		"armada_advancedradartower_scav",
		"armada_veil_scav",
		"armada_tracer_scav",
		"armada_pinpointer_scav",
		"armada_keeper_scav",
		"armada_pitbull_scav",
		"armada_rattlesnake_scav",
		"armada_arbalest_scav",
		"cortex_advancedradartower_scav",
		"cortex_shroud_scav",
		"cortex_nemesis_scav",
		"cortex_pinpointer_scav",
		"cortex_overseer_scav",
		"corhllllt_scav",
		"cortex_scorpion_scav",
		"cortex_persecutor_scav",
		"corflak_scav",

		-- Nanos
		"armada_constructionturret_scav",
		"cortex_constructionturret_scav",

		-- T3
		"armada_pulsar_scav",
		"armada_basilica_scav",
		"armminivulc_scav",
		"armada_mercury_scav",
		"armada_paralyzer_scav",
		"armada_citadel_scav",
		"cortex_calamity_scav",
		"cortex_basilisk_scav",
		"corminibuzz_scav",
		"cortex_screamer_scav",
		"cortex_catalyst_scav",
		"corfmd_scav",
	},

	T4 = {
		-- Nanos
		"armada_constructionturret_scav",
		"cortex_constructionturret_scav",

		-- T2
		"armada_advancedradartower_scav",
		"armada_veil_scav",
		"armada_tracer_scav",
		"armada_pinpointer_scav",
		"armada_keeper_scav",
		"armada_pitbull_scav",
		"armada_rattlesnake_scav",
		"armada_arbalest_scav",
		"cortex_advancedradartower_scav",
		"cortex_shroud_scav",
		"cortex_nemesis_scav",
		"cortex_pinpointer_scav",
		"cortex_overseer_scav",
		"corhllllt_scav",
		"cortex_scorpion_scav",
		"cortex_persecutor_scav",
		"corflak_scav",

		-- Nanos
		"armada_constructionturret_scav",
		"cortex_constructionturret_scav",

		-- T3
		"armada_pulsar_scav",
		"armada_basilica_scav",
		"armminivulc_scav",
		"armada_mercury_scav",
		"armada_paralyzer_scav",
		"armada_citadel_scav",
		"cortex_calamity_scav",
		"cortex_basilisk_scav",
		"corminibuzz_scav",
		"cortex_screamer_scav",
		"cortex_catalyst_scav",
		"corfmd_scav",
		
		-- Nanos
		"armada_constructionturret_scav",
		"cortex_constructionturret_scav",

		-- T4
		"armada_pulsart3_scav",
		"armada_ragnarok_scav",
		"armbotrail_scav",
		"armada_armageddon_scav",
		"cortex_calamityt3_scav",
		"cortex_calamity_scav",
		"cortex_apocalypse_scav",
	},
}

local beaconDefencesSea = {
	T0 = {
		-- Nanos
		"armada_navalconstructionturret_scav",
		"cortex_navalconstructionturret_scav",
		
		-- T0
		"armada_harpoon_scav",
		"armada_navalnettle_scav",
		"cortex_urchin_scav",
		"cortex_slingshot_scav",
	},

	T1 = {
		-- Nanos
		"armada_navalconstructionturret_scav",
		"cortex_navalconstructionturret_scav",
		
		-- T1
		"armada_navalradarsonar_scav",
		"armada_manta_scav",
		"cortex_radarsonartower_scav",
		"cortex_coral_scav",
	},

	T2 = {
		-- Nanos
		"armada_navalconstructionturret_scav",
		"cortex_navalconstructionturret_scav",
		
		-- T2
		"armada_gorgon_scav",
		"armada_navalarbalest_scav",
		"armada_moray_scav",
		"armada_navalpinpointer_scav",
		"cortex_devastator_scav",
		"cortex_navalbirdshot_scav",
		"cortex_lamprey_scav",
		"cortex_navalpinpointer_scav",
	},
  
	T3 = {
		-- Nanos
		"armada_navalconstructionturret_scav",
		"cortex_navalconstructionturret_scav",
		
		-- T2 -- There's nothing to put in T3 :(
		"armada_gorgon_scav",
		"armada_navalarbalest_scav",
		"armada_moray_scav",
		"armada_navalpinpointer_scav",
		"cortex_devastator_scav",
		"cortex_navalbirdshot_scav",
		"cortex_lamprey_scav",
		"cortex_navalpinpointer_scav",
	},

	T4 = {
		-- Nanos
		"armada_navalconstructionturret_scav",
		"cortex_navalconstructionturret_scav",
		
		-- T2 -- There's nothing to put in T4 either :(
		"armada_gorgon_scav",
		"armada_navalarbalest_scav",
		"armada_moray_scav",
		"armada_navalpinpointer_scav",
		"cortex_devastator_scav",
		"cortex_navalbirdshot_scav",
		"cortex_lamprey_scav",
		"cortex_navalpinpointer_scav",
	},
}

local noSelfDestructID = getUnitIDList(noSelfDestruct)
local wallsID = getUnitIDList(walls)
local stockpilersID = getUnitIDList(stockpilers)
local nukesID = getUnitIDList(nukes)
local beaconCaptureExclusionsID = getUnitIDList(beaconCaptureExclusions)

return {
	scavSpawnEffectUnit = scavSpawnEffectUnit,
	scavSpawnEffectUnitID = scavSpawnEffectUnitID,
	friendlySpawnEffectUnit = friendlySpawnEffectUnit,
	friendlySpawnEffectUnitID = friendlySpawnEffectUnitID,
	scavSpawnBeacon = scavSpawnBeacon,
	scavSpawnBeaconID = scavSpawnBeaconID,
	NoSelfDestruct = noSelfDestruct,
	NoSelfDestructID = noSelfDestructID,
	Walls = walls,
	WallsID = wallsID,
	Stockpilers = stockpilers,
	StockpilersID = stockpilersID,
	Nukes = nukes,
	NukesID = nukesID,
	BeaconCaptureExclusions = beaconCaptureExclusions,
	BeaconCaptureExclusionsID = beaconCaptureExclusionsID,
	BeaconDefencesLand = beaconDefencesLand,
	BeaconDefencesSea = beaconDefencesSea,
}