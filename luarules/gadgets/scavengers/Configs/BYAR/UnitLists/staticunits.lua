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
	"armclaw_scav",
	"corfmd_scav",
	"armamd_scav",
	"lootboxgold_scav",
	"lootboxplatinum_scav",
	"lootboxsilver_scav",
	"lootboxbronze_scav",
	"chicken_turrets",
	"chicken_hive",
	"corscavdtl_scav",
	"corscavdtf_scav",
	"corscavdtm_scav",
}

local walls = {
	"armdrag_scav",
	"armfdrag_scav",
	"cordrag_scav",
	"corfdrag_scav",
	"armfort_scav",
	"corfort_scav",
	"corscavdrag_scav",
	"corscavfort_scav",
}

local stockpilers = {
	"corsilo_scav",
	"armsilo_scav",
	"cortron_scav",
	"armemp_scav",
	"armamd_scav",
	"corfmd_scav",
	"corscreamer_scav",
	"armmercury_scav",
	"corjuno_scav",
	"armjuno_scav",
	"armthor_scav",
	"armscab_scav",
	"cormabm_scav",
	"armcarry_scav",
	"corcarry_scav",
	"armbotrail_scav",
}

local nukes = {
	"corsilo_scav",
	"armsilo_scav",
	"cortron_scav",
	"armemp_scav",
	"corjuno_scav",
	"armjuno_scav",
}

local beaconCaptureExclusions = {
	"armdrag",
	"armfdrag",
	"cordrag",
	"corfdrag",
	"armfort",
	"corfort",
}

local beaconDefencesLand = {
	T0 = {
		-- Nanos
		"armnanotc_scav",
		"cornanotc_scav",

		-- T0
		"armllt_scav",
		"armrl_scav",
		"corllt_scav",
		"corrl_scav",
	},

	T1 = {
		-- Nanos
		"armnanotc_scav",
		"cornanotc_scav",

		-- T1
		"armrad_scav",
		"armjamt_scav",
		"armbeamer_scav",
		"armhlt_scav",
		"armguard_scav",
		"armmg_scav",
		"armrl_scav",
		"armferret_scav",
		"armcir_scav",
		"armdl_scav",
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
		"armnanotc_scav",
		"cornanotc_scav",

		-- T1
		"armrad_scav",
		"armjamt_scav",
		"armbeamer_scav",
		"armhlt_scav",
		"armguard_scav",
		"armmg_scav",
		"armrl_scav",
		"armferret_scav",
		"armcir_scav",
		"armdl_scav",
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
		"armnanotc_scav",
		"cornanotc_scav",

		-- T2
		"armarad_scav",
		"armveil_scav",
		"armsd_scav",
		"armtarg_scav",
		"armgate_scav",
		"armpb_scav",
		"armamb_scav",
		"armflak_scav",
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
		"armnanotc_scav",
		"cornanotc_scav",

		-- T2
		"armarad_scav",
		"armveil_scav",
		"armsd_scav",
		"armtarg_scav",
		"armgate_scav",
		"armpb_scav",
		"armamb_scav",
		"armflak_scav",
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
		"armnanotc_scav",
		"cornanotc_scav",

		-- T3
		"armanni_scav",
		"armbrtha_scav",
		"armminivulc_scav",
		"armmercury_scav",
		"armemp_scav",
		"armamd_scav",
		"cordoom_scav",
		"corint_scav",
		"corminibuzz_scav",
		"corscreamer_scav",
		"cortron_scav",
		"corfmd_scav",
	},

	T4 = {
		-- Nanos
		"armnanotc_scav",
		"cornanotc_scav",

		-- T2
		"armarad_scav",
		"armveil_scav",
		"armsd_scav",
		"armtarg_scav",
		"armgate_scav",
		"armpb_scav",
		"armamb_scav",
		"armflak_scav",
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
		"armnanotc_scav",
		"cornanotc_scav",

		-- T3
		"armanni_scav",
		"armbrtha_scav",
		"armminivulc_scav",
		"armmercury_scav",
		"armemp_scav",
		"armamd_scav",
		"cordoom_scav",
		"corint_scav",
		"corminibuzz_scav",
		"corscreamer_scav",
		"cortron_scav",
		"corfmd_scav",
		
		-- Nanos
		"armnanotc_scav",
		"cornanotc_scav",

		-- T4
		"armannit3_scav",
		"armvulc_scav",
		"armbotrail_scav",
		"armsilo_scav",
		"cordoomt3_scav",
		"corbuzz_scav",
		"corsilo_scav",
	},
}

local beaconDefencesSea = {
	T0 = {
		-- Nanos
		"armnanotcplat_scav",
		"cornanotcplat_scav",
		
		-- T0
		"armtl_scav",
		"armfrt_scav",
		"cortl_scav",
		"corfrt_scav",
	},

	T1 = {
		-- Nanos
		"armnanotcplat_scav",
		"cornanotcplat_scav",
		
		-- T1
		"armfrad_scav",
		"armfhlt_scav",
		"corfrad_scav",
		"corfhlt_scav",
	},

	T2 = {
		-- Nanos
		"armnanotcplat_scav",
		"cornanotcplat_scav",
		
		-- T2
		"armkraken_scav",
		"armfflak_scav",
		"armatl_scav",
		"armfatf_scav",
		"corfdoom_scav",
		"corenaa_scav",
		"coratl_scav",
		"corfatf_scav",
	},
  
	T3 = {
		-- Nanos
		"armnanotcplat_scav",
		"cornanotcplat_scav",
		
		-- T2 -- There's nothing to put in T3 :(
		"armkraken_scav",
		"armfflak_scav",
		"armatl_scav",
		"armfatf_scav",
		"corfdoom_scav",
		"corenaa_scav",
		"coratl_scav",
		"corfatf_scav",
	},

	T4 = {
		-- Nanos
		"armnanotcplat_scav",
		"cornanotcplat_scav",
		
		-- T2 -- There's nothing to put in T4 either :(
		"armkraken_scav",
		"armfflak_scav",
		"armatl_scav",
		"armfatf_scav",
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