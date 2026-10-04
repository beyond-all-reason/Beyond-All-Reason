local units = {}
local def = {
    maxacc = 0,
	blocking = false,
	maxdec = 0,
	energycost = 10000,
	metalcost = 1000,
	buildpic = "ARMSTONE.DDS",
	buildtime = 10000,
	canattack = false,
	cancloak = true,
	canrepeat = false,
	capturable = true,
	cantbetransported = false,
	category = "OBJECT",
	collisionvolumeoffsets = "0 0 0",
	collisionvolumescales = "0.1 0.1 0.1",
	collisionvolumetype = "CylY",
	crushresistance = 2500,
	footprintx = 1,
	footprintz = 1,
	hidedamage = true,
	autoheal = 100000, --so it doesnt die
	mass = 0,
	health = 5600000,
	maxslope = 64,
	maxwaterdepth = 1000,
	movementclass = "NANO",
	reclaimable = false,
	repairable = false,
	script = "blank.cob", --"hats/hat.cob",
	seismicsignature = 0,
	sightdistance = 1,
	sonarstealth = true,
	stealth = true,
	upright = false,
	customparams = {
		nohealthbars = true,
		model_author = "Protar", -- Gloves only, unit by Mr Bob
		normaltex = "unittextures/cor_normal.dds",
		subfolder = "other/hats",
		decoration = 1,
	},
}

units["arm_leftshoulder_nationwars_eec"] = table.copy(def)
units["arm_leftshoulder_nationwars_eec"].objectname = "hats/arm_leftshoulder_nationwars_eec.s3o"
units["arm_leftshoulder_nationwars_eec"].customparams.normaltex = "unittextures/arm_normal.dds"

units["arm_leftshoulder_nationwars_ger"] = table.copy(def)
units["arm_leftshoulder_nationwars_ger"].objectname = "hats/arm_leftshoulder_nationwars_ger.s3o"
units["arm_leftshoulder_nationwars_ger"].customparams.normaltex = "unittextures/arm_normal.dds"

units["arm_leftshoulder_nationwars_us"] = table.copy(def)
units["arm_leftshoulder_nationwars_us"].objectname = "hats/arm_leftshoulder_nationwars_us.s3o"
units["arm_leftshoulder_nationwars_us"].customparams.normaltex = "unittextures/arm_normal.dds"

units["cor_leftshoulder_nationwars_eec"] = table.copy(def)
units["cor_leftshoulder_nationwars_eec"].objectname = "hats/cor_leftshoulder_nationwars_eec.s3o"

units["cor_leftshoulder_nationwars_ger"] = table.copy(def)
units["cor_leftshoulder_nationwars_ger"].objectname = "hats/cor_leftshoulder_nationwars_ger.s3o"

units["cor_leftshoulder_nationwars_us"] = table.copy(def)
units["cor_leftshoulder_nationwars_us"].objectname = "hats/cor_leftshoulder_nationwars_us.s3o"

return units