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
	"cormaw_scav",
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
	"cordrag_scav",
	"corfdrag_scav",
	"armada_fortificationwall_scav",
	"corfort_scav",
	"corscavdrag_scav",
	"corscavfort_scav",
}

local stockpilers = {
	"corsilo_scav",
	"armada_armageddon_scav",
	"cortron_scav",
	"armada_paralyzer_scav",
	"armada_citadel_scav",
	"corfmd_scav",
	"corscreamer_scav",
	"armada_mercury_scav",
	"corjuno_scav",
	"armada_juno_scav",
	"armthor_scav",
	"armada_umbrella_scav",
	"cormabm_scav",
	"armada_haven_scav",
	"corcarry_scav",
	"armbotrail_scav",
}

local nukes = {
	"corsilo_scav",
	"armada_armageddon_scav",
	"cortron_scav",
	"armada_paralyzer_scav",
	"corjuno_scav",
	"armada_juno_scav",
}

local beaconCaptureExclusions = {
	"armada_dragonsteeth",
	"armada_sharksteeth",
	"cordrag",
	"corfdrag",
	"armada_fortificationwall",
	"corfort",
}

local beaconDefencesLand = {
	T0 = {
		-- Nanos
		"armada_constructionturret_scav",
		"cornanotc_scav",

		-- T0
		"armada_sentry_scav",
		"armada_nettle_scav",
		"corllt_scav",
		"corrl_scav",
	},

	T1 = {
		-- Nanos
		"armada_constructionturret_scav",
		"cornanotc_scav",

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
		"corrad_scav",
		"corjamt_scav",
		"corhllt_scav",
		"corhlt_scav",
		"corpun_scav",
		"cormadsam_scav",
		"corerad_scav",
		"cordl_scav",
		"corscavdtl_scav",
		"corscavdtf_scav",
		"corscavdtm_scav",
	},

	T2 = {
		-- Nanos
		"armada_constructionturret_scav",
		"cornanotc_scav",

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
		"corrad_scav",
		"corjamt_scav",
		"corhllt_scav",
		"corhlt_scav",
		"corpun_scav",
		"cormadsam_scav",
		"corerad_scav",
		"cordl_scav",
		"corscavdtl_scav",
		"corscavdtf_scav",
		"corscavdtm_scav",
		
		-- Nanos
		"armada_constructionturret_scav",
		"cornanotc_scav",

		-- T2
		"armada_advancedradartower_scav",
		"armada_veil_scav",
		"armada_tracer_scav",
		"armada_pinpointer_scav",
		"armada_keeper_scav",
		"armada_pitbull_scav",
		"armada_rattlesnake_scav",
		"armada_arbalest_scav",
		"corarad_scav",
		"corshroud_scav",
		"corsd_scav",
		"cortarg_scav",
		"corgate_scav",
		"corhllllt_scav",
		"corvipe_scav",
		"cortoast_scav",
		"corflak_scav",
	},

	T3 = {
		-- Nanos
		"armada_constructionturret_scav",
		"cornanotc_scav",

		-- T2
		"armada_advancedradartower_scav",
		"armada_veil_scav",
		"armada_tracer_scav",
		"armada_pinpointer_scav",
		"armada_keeper_scav",
		"armada_pitbull_scav",
		"armada_rattlesnake_scav",
		"armada_arbalest_scav",
		"corarad_scav",
		"corshroud_scav",
		"corsd_scav",
		"cortarg_scav",
		"corgate_scav",
		"corhllllt_scav",
		"corvipe_scav",
		"cortoast_scav",
		"corflak_scav",

		-- Nanos
		"armada_constructionturret_scav",
		"cornanotc_scav",

		-- T3
		"armada_pulsar_scav",
		"armada_basilica_scav",
		"armminivulc_scav",
		"armada_mercury_scav",
		"armada_paralyzer_scav",
		"armada_citadel_scav",
		"cordoom_scav",
		"corint_scav",
		"corminibuzz_scav",
		"corscreamer_scav",
		"cortron_scav",
		"corfmd_scav",
	},

	T4 = {
		-- Nanos
		"armada_constructionturret_scav",
		"cornanotc_scav",

		-- T2
		"armada_advancedradartower_scav",
		"armada_veil_scav",
		"armada_tracer_scav",
		"armada_pinpointer_scav",
		"armada_keeper_scav",
		"armada_pitbull_scav",
		"armada_rattlesnake_scav",
		"armada_arbalest_scav",
		"corarad_scav",
		"corshroud_scav",
		"corsd_scav",
		"cortarg_scav",
		"corgate_scav",
		"corhllllt_scav",
		"corvipe_scav",
		"cortoast_scav",
		"corflak_scav",

		-- Nanos
		"armada_constructionturret_scav",
		"cornanotc_scav",

		-- T3
		"armada_pulsar_scav",
		"armada_basilica_scav",
		"armminivulc_scav",
		"armada_mercury_scav",
		"armada_paralyzer_scav",
		"armada_citadel_scav",
		"cordoom_scav",
		"corint_scav",
		"corminibuzz_scav",
		"corscreamer_scav",
		"cortron_scav",
		"corfmd_scav",
		
		-- Nanos
		"armada_constructionturret_scav",
		"cornanotc_scav",

		-- T4
		"armada_pulsart3_scav",
		"armada_ragnarok_scav",
		"armbotrail_scav",
		"armada_armageddon_scav",
		"cordoomt3_scav",
		"corbuzz_scav",
		"corsilo_scav",
	},
}

local beaconDefencesSea = {
	T0 = {
		-- Nanos
		"armada_constructionturretplat_scav",
		"cornanotcplat_scav",
		
		-- T0
		"armada_harpoon_scav",
		"armada_navalnettle_scav",
		"cortl_scav",
		"corfrt_scav",
	},

	T1 = {
		-- Nanos
		"armada_constructionturretplat_scav",
		"cornanotcplat_scav",
		
		-- T1
		"armada_navalradar_scav",
		"armada_manta_scav",
		"corfrad_scav",
		"corfhlt_scav",
	},

	T2 = {
		-- Nanos
		"armada_constructionturretplat_scav",
		"cornanotcplat_scav",
		
		-- T2
		"armada_gorgon_scav",
		"armada_navalarbalest_scav",
		"armada_moray_scav",
		"armada_navalpinpointer_scav",
		"corfdoom_scav",
		"corenaa_scav",
		"coratl_scav",
		"corfatf_scav",
	},
  
	T3 = {
		-- Nanos
		"armada_constructionturretplat_scav",
		"cornanotcplat_scav",
		
		-- T2 -- There's nothing to put in T3 :(
		"armada_gorgon_scav",
		"armada_navalarbalest_scav",
		"armada_moray_scav",
		"armada_navalpinpointer_scav",
		"corfdoom_scav",
		"corenaa_scav",
		"coratl_scav",
		"corfatf_scav",
	},

	T4 = {
		-- Nanos
		"armada_constructionturretplat_scav",
		"cornanotcplat_scav",
		
		-- T2 -- There's nothing to put in T4 either :(
		"armada_gorgon_scav",
		"armada_navalarbalest_scav",
		"armada_moray_scav",
		"armada_navalpinpointer_scav",
		"corfdoom_scav",
		"corenaa_scav",
		"coratl_scav",
		"corfatf_scav",
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